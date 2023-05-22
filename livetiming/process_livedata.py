import redis.asyncio as redis
import aiokafka
import asyncio
import ujson
import zlib
import base64
import random


class ProcessLiveData:
    """
    A client for processing live data captured by fastf1-livetiming.signalrc_client.py.

    Args:
        redis_url (str) : url of the redis data structure server where data is cached
        kafka_url (str) : url of the kafka server
        logger (Logger or None) : By default, errors are logged to the
            console. If you wish to customize logging, you can pass an
            instance of :class:`logging.Logger` (see: :mod:`logging`).
    """

    def __init__(
        self,
        startingPositions: list[int],
        redis_url="localhost",
        kafka_url="localhost:9092",
    ):
        self._redis = redis.Redis(host=redis_url, decode_responses=True)
        self._kafka = aiokafka.AIOKafkaProducer(
            bootstrap_servers=kafka_url,
            key_serializer=self._serializer,
            value_serializer=self._serializer,
            partitioner=self._paritioner,
        )

        self.sessionStatus = None
        self.retiredDrivers = set()
        self.startingPositions = startingPositions

        # Assign a Kafka partition to each driver for this session
        self.partitionMap = {}
        for i, item in enumerate(startingPositions):
            self.partitionMap[str(item).encode()] = i

    async def start(self):
        await self._redis.flushall()
        for i, item in enumerate(self.startingPositions):
            await self._redis.hset(name=str(item), key="Position", value=str(i + 1))
        await self._kafka.start()

    async def stop(self):
        await self._redis.bgsave()
        await self._kafka.stop()

    def _convert_to_timestamp(self, timeStr) -> float:
        """F1 sends a non standard timestamp with all of their messages
        Some have varying precision of microseconds
        Some does not have microseconds at all
        """

        # Includes microseconds
        if len(timeStr) > 20:
            timeStr = timeStr.split(".")
            microseconds = timeStr[1][:-1]
            # python datetime only supports a precision of 6 digits in microseconds
            if len(microseconds) > 6:
                microseconds = microseconds[:6]
            return datetime.datetime.strptime(
                timeStr[0] + "." + microseconds, "%Y-%m-%dT%H:%M:%S.%f"
            ).timestamp()
        else:  # Only up till seconds
            timeStr = timeStr[:-1]
            return datetime.datetime.strptime(timeStr, "%Y-%m-%dT%H:%M:%S").timestamp()

    async def _get_current_lap(self, driver) -> int:
        """Get current lap any driver is on"""
        curLap = await self._redis.hget(name=driver, key="CurrentLap")
        if curLap is None:
            return 1
        return int(curLap.split("::")[0])

    async def _get_fastest_lap(self, driver) -> float:
        """Get fastest lap for any driver"""
        fastest = await self._redis.hget(name=driver, key="FastestLap")
        if fastest is None:
            return float("inf")
        return float(fastest)

    async def _get_fastest_sector(self, driver, sector) -> float:
        """Get fastest sector for any driver"""
        fastest = await self._redis.hget(name=driver, key=f"FastestSector{sector}")
        if fastest is None:
            return float("inf")
        return float(fastest)

    def _serializer(self, value) -> bytes:
        if not isinstance(value, str):
            value = str(value)
        return value.encode()

    def _paritioner(self, key_bytes, all_partitions, available_partitions):
        """All 20 drivers have their own partition in any driver related Kafka topic
        This ensures that message order is always preserved and allows for load-balacing
        across multiple brokes"""
        if key_bytes in self.partitionMap:
            return self.partitionMap[key_bytes]
        return random.choice(all_partitions)

    async def _process_timing_app_data(self, msg, timestamp):
        """
        Processes data from https://livetiming.formula1.com/static/.../TimingAppData.jsonStream

        The following information is present in the file:
            (1) TotaLaps done on a certain tyre
            (2) Stint Number
            (3) LapTime of a given LapNumber
            (4) Compound type of tyre changed in pitstop
                (a) Age of tyres fitted in pitstop
        """

        msg = msg["Lines"]
        tasks = []

        # msg may contain information for more than 1 driver, where driver no. is the key
        for driver in msg:
            # Filter out noise. All important information is under key "Stints"
            if "Stints" in msg[driver]:
                for curStint in msg[driver]["Stints"]:
                    if not isinstance(curStint, str):
                        continue

                    indvData = msg[driver]["Stints"][curStint]

                    # TotalLaps is the number of laps driven on current set of tyres
                    # Includes laps driven on other sessions

                    if "TotalLaps" in indvData:
                        curLap = await self._get_current_lap(driver)
                        tasks.append(
                            self._redis.hset(
                                name=f"{driver}:{curLap}",
                                mapping={
                                    "TyreAge": f'{indvData["TotalLaps"]}::{timestamp}',
                                    "StintNumber": f"{curStint}::{timestamp}",
                                },
                            )
                        )

                        tasks.append(
                            self._kafka.send(
                                topic="TyreAge",
                                value=f'{indvData["TotalLaps"]},{curStint},{curLap}::{timestamp}',
                                key=driver,
                            )
                        )

                    if ("LapTime" in indvData) and ("LapNumber" in indvData):
                        tasks.append(
                            self._redis.hset(
                                name=f'{driver}:{int(indvData["LapNumber"]) - 1}',
                                key="LapTime",
                                value=f'{indvData["LapTime"]}::{timestamp}',
                            )
                        )

                        tasks.append(
                            self._kafka.send(
                                topic="LapTime",
                                key=driver,
                                value=f'{indvData["LapTime"]},{int(indvData["LapNumber"]) - 1}::{timestamp}',
                            )
                        )

                    if ("Compound" in indvData) and (indvData["Compound"] != "UNKNOWN"):
                        curLap = await self._get_current_lap(driver)
                        mapping = {
                            "TyreType": f'{indvData["Compound"]}::{timestamp}',
                            "StintNumber": f"{curStint}::{timestamp}",
                        }

                        # On the event that a cars pitbox is before the start/finish line,
                        # the new tyre is fitted in the current lap, although it should only
                        # be counted as having been fitted from the next lap onward
                        if await self._redis.hexists(
                            name=f"{driver}:{curLap}", key="PitIn"
                        ):
                            curLap += 1

                        tasks.append(
                            self._redis.hset(
                                name=f"{driver}:{curLap}",
                                mapping=mapping,
                            )
                        )

                        tasks.append(
                            self._kafka.send(
                                topic="Tyre",
                                key=driver,
                                value=f'{indvData["Compound"]},{curStint},{curLap}::{timestamp}',
                            )
                        )

        await asyncio.gather(*tasks)

    async def _process_timing_data(self, msg, timestamp):
        """
        Processes data from https://livetiming.formula1.com/static/.../TimingData.jsonStream

        The following information is present in the file:
            (1) GapToLeader (Stream)
            (2) IntervalToPositionAhead (Stream)
            (3) Individual sector time
            (4) Speed trap speed
            (5) Pit stop entry and exit
        """

        msg = msg["Lines"]
        tasks = []

        # msg may contain information for more than 1 driver, where driver no. is the key
        for driver in msg:
            if "GapToLeader" in msg[driver]:
                # Live data sometimes has wrong data under GapToLeader
                if "+" in msg[driver]["GapToLeader"]:
                    curLap = await self._get_current_lap(driver)
                    tasks.append(
                        self._redis.hset(
                            name=f"{driver}:{curLap}:GapToLeader",
                            key=timestamp,
                            value=f'{msg[driver]["GapToLeader"]}',
                        )
                    )

                    tasks.append(
                        self._kafka.send(
                            topic="GapToLeader",
                            key=driver,
                            value=f'{msg[driver]["GapToLeader"]},{curLap}::{timestamp}',
                        )
                    )

            if ("IntervalToPositionAhead" in msg[driver]) and (
                "Value" in msg[driver]["IntervalToPositionAhead"]
            ):
                if "+" in msg[driver]["IntervalToPositionAhead"]["Value"]:
                    curLap = await self._get_current_lap(driver)
                    tasks.append(
                        self._redis.hset(
                            name=f"{driver}:{curLap}:IntervalToPositionAhead",
                            key=timestamp,
                            value=f'{msg[driver]["IntervalToPositionAhead"]["Value"]}',
                        )
                    )

                    tasks.append(
                        self._kafka.send(
                            topic="IntervalToPositionAhead",
                            key=driver,
                            value=f'{msg[driver]["IntervalToPositionAhead"]["Value"]},{curLap}::{timestamp}',
                        )
                    )

            if ("Sectors" in msg[driver]) and (
                isinstance(msg[driver]["Sectors"], dict)
            ):
                for indvSector in msg[driver]["Sectors"]:
                    if ("Value" in msg[driver]["Sectors"][indvSector]) and (
                        msg[driver]["Sectors"][indvSector]["Value"] != ""
                    ):
                        curLap = await self._get_current_lap(driver)
                        sectorNumber = int(indvSector) + 1
                        sectorTime = msg[driver]["Sectors"][indvSector]["Value"]

                        tasks.append(
                            self._redis.hset(
                                name=f"{driver}:{curLap}",
                                key=f"Sector{sectorNumber}Time",
                                value=f"{sectorTime}::{timestamp}",
                            )
                        )

                        tasks.append(
                            self._kafka.send(
                                topic="SectorTime",
                                key=driver,
                                value=f"{sectorTime},{sectorNumber},{curLap}::{timestamp}",
                            )
                        )

                        # Check if sector was faster than fastest sector and update accordingly
                        fastestSector = await self._get_fastest_sector(
                            driver, sectorNumber
                        )
                        if float(sectorTime) < fastestSector:
                            await self._redis.hset(
                                name=driver,
                                key=f"FastestSector{sectorNumber}",
                                value=sectorTime,
                            )

                            tasks.append(
                                self._kafka.send(
                                    topic="Fastest",
                                    key=driver,
                                    value=f"Sector{sectorNumber},{curLap}::{timestamp}",
                                )
                            )

                        # If driver has a sector 3 time, he has crossed the start/finish line
                        # LapTime is calculated from summing individual sectors
                        if sectorNumber == 3:
                            sector1Time = await self._redis.hget(
                                name=f"{driver}:{curLap}", key="Sector1Time"
                            )
                            sector2Time = await self._redis.hget(
                                name=f"{driver}:{curLap}", key="Sector2Time"
                            )

                            # We only calculate LapTime if all 3 sectors are present. Otherwise, it is an outlap or red flagged lap
                            if (sector1Time is not None) and (sector2Time is not None):
                                sector1Time = sector1Time.split("::")[0]
                                sector2Time = sector2Time.split("::")[0]

                                lapTime = (
                                    float(sector1Time)
                                    + float(sector2Time)
                                    + float(sectorTime)
                                )
                                lapTime = round(lapTime, 3)

                                # Check if lap was faster than fastest lap and update accordingly
                                fastestLap = await self._get_fastest_lap(driver)
                                if lapTime < fastestLap:
                                    await self._redis.hset(
                                        name=driver, key="FastestLap", value=lapTime
                                    )

                                    tasks.append(
                                        self._kafka.send(
                                            topic="Fastest",
                                            key=driver,
                                            value=f"LapTime,{curLap}::{timestamp}",
                                        )
                                    )

                                min = int(lapTime // 60)
                                remainder = str(round(lapTime % 60, 3)).split(".")
                                sec = remainder[0]
                                ms = remainder[1][:3]

                                lapTime = f"{min}:{sec:0>2}.{ms}"

                                tasks.append(
                                    self._redis.hset(
                                        name=f"{driver}:{curLap}",
                                        key="LapTime",
                                        value=f"{lapTime}::{timestamp}",
                                    )
                                )

                                tasks.append(
                                    self._kafka.send(
                                        topic="LapTime",
                                        key=driver,
                                        value=f"{lapTime},{curLap}::{timestamp}",
                                    )
                                )

                            # If driver crossed start/finish line and is not currently in the pits, start a new lap
                            if (
                                await self._redis.hexists(
                                    name=f"{driver}:{curLap}", key="PitIn"
                                )
                                is False
                            ):
                                tasks.append(
                                    self._redis.hset(
                                        name=driver,
                                        key="CurrentLap",
                                        value=f"{curLap + 1}::{timestamp}",
                                    )
                                )

                                tasks.append(
                                    self._kafka.send(
                                        topic="CurrentLap",
                                        key=driver,
                                        value=f"{curLap + 1}::{timestamp}",
                                    )
                                )

            if "Speeds" in msg[driver]:
                for indvSpeed in msg[driver]["Speeds"]:
                    speedTrap = msg[driver]["Speeds"][indvSpeed]
                    curLap = await self._get_current_lap(driver)

                    mapping = {}
                    if ("Value" in speedTrap) and (speedTrap["Value"] != ""):
                        if indvSpeed == "I1":
                            mapping = {
                                "Sector1SpeedTrap": f'{speedTrap["Value"]}::{timestamp}'
                            }
                        elif indvSpeed == "I2":
                            mapping = {
                                "Sector2SpeedTrap": f'{speedTrap["Value"]}::{timestamp}'
                            }
                        elif indvSpeed == "FL":
                            # FL speed could arrive after sector 3 time and new lap is created.
                            # If sector 2 time does not exist, FL speed should be added to previous lap

                            if (
                                await self._redis.hexists(
                                    name=f"{driver}:{curLap}", key="Sector2Time"
                                )
                                is False
                            ):
                                curLap -= 1

                            mapping = {
                                "FinishLineSpeedTrap": f'{speedTrap["Value"]}::{timestamp}'
                            }
                        elif indvSpeed == "ST":
                            mapping = {
                                "BackStraightSpeedTrap": f'{speedTrap["Value"]}::{timestamp}'
                            }

                        tasks.append(
                            self._redis.hset(
                                name=f"{driver}:{curLap}",
                                mapping=mapping,
                            )
                        )

                        _STIdentifier = next(iter(mapping))
                        tasks.append(
                            self._kafka.send(
                                topic="Speed",
                                key=driver,
                                value=f'{_STIdentifier},{mapping[_STIdentifier].split("::")[0]},{curLap}::{timestamp}',
                            )
                        )

                    # TODO: Process personal/fastest speeds on speed traps

            if "InPit" in msg[driver]:
                if msg[driver]["InPit"] is True:
                    # Driver just entered pit
                    curLap = await self._get_current_lap(driver)

                    tasks.append(
                        self._redis.hset(
                            name=f"{driver}:{curLap}",
                            key="PitIn",
                            value=timestamp,
                        )
                    )

                    tasks.append(
                        self._kafka.send(
                            topic="PitIn", key=driver, value=f"{curLap}::{timestamp}"
                        )
                    )

                    if "NumberOfPitStops" in msg[driver]:
                        tasks.append(
                            self._redis.hset(
                                name=driver,
                                key="NumberOfPitStops",
                                value=f'{msg[driver]["NumberOfPitStops"]}::{timestamp}',
                            )
                        )

                        tasks.append(
                            self._kafka.send(
                                topic="NumberOfPitStops",
                                key=driver,
                                value=f'{msg[driver]["NumberOfPitStops"]}::{timestamp}',
                            )
                        )

                else:
                    # Driver just exited pit
                    curLap = await self._get_current_lap(driver)

                    # Start a new lap when driver exits pit
                    tasks.append(
                        self._redis.hset(
                            name=driver,
                            key="CurrentLap",
                            value=f"{curLap + 1}::{timestamp}",
                        )
                    )

                    tasks.append(
                        self._kafka.send(
                            topic="CurrentLap",
                            key=driver,
                            value=f"{curLap + 1}::{timestamp}",
                        )
                    )

                    tasks.append(
                        self._redis.hset(
                            name=f"{driver}:{curLap}",
                            key="PitOut",
                            value=timestamp,
                        )
                    )

                    tasks.append(
                        self._kafka.send(
                            topic="PitOut", key=driver, value=f"{curLap}::{timestamp}"
                        )
                    )

                # TODO: Use timestamps to determine pit stop time

        await asyncio.gather(*tasks)

    async def _process_lap_count(self, msg, timestamp):
        """
        Processes data from https://livetiming.formula1.com/static/.../LapCount.jsonStream

        The following information is present in the file:
            (1) Current lap of race, set by race leader
            (2) Total laps in race
        """

        tasks = []

        if "TotalLaps" in msg:  # CurrentLap == 1
            # CurrentLap may be = 1 although session has not started yet
            # Check SessionData.jsonStream for cue to start of session
            tasks.append(
                self._redis.hset(
                    name="Session",
                    key="TotalLaps",
                    value=f'{msg["TotalLaps"]}::{timestamp}',
                )
            )

            tasks.append(
                self._kafka.send(
                    topic="TotalLaps",
                    key="TotalLaps",
                    value=f'{msg["TotalLaps"]}::{timestamp}',
                )
            )

        tasks.append(
            self._redis.hset(
                name="Session",
                key="CurrentLap",
                value=f'{msg["CurrentLap"]}::{timestamp}',
            )
        )

        tasks.append(
            self._kafka.send(
                topic="LapCount",
                key="CurrentLap",
                value=f'{msg["CurrentLap"]}::{timestamp}',
            )
        )

        await asyncio.gather(*tasks)

    async def _process_session_data(self, msg, timestamp):
        """
        Processes data from https://livetiming.formula1.com/static/.../SessionData.jsonStream

        The following information is present in the file:
            (1) Session start time
            (2) Session end time
        """

        tasks = []

        if self._get_session_status(msg) == "Started":
            self.sessionStatus = "Started"
            tasks.append(
                self._redis.hset(name="Session", key="StartTime", value=timestamp)
            )
            tasks.append(
                self._kafka.send(
                    topic="SessionStatus", key="StartTime", value=timestamp
                )
            )

            await asyncio.gather(*tasks)

        elif self._get_session_status(msg) == "Finalised":
            tasks.append(
                self._redis.hset(name="Session", key="EndTime", value=timestamp)
            )
            tasks.append(
                self._kafka.send(topic="SessionStatus", key="EndTime", value=timestamp)
            )

            await asyncio.gather(*tasks)
            # TODO: Add logic to shutdown server

        elif self._get_session_status(msg) == "Aborted":
            self.sessionStatus = "Aborted"

    def _get_session_status(self, d):
        """Find SessionStatus key inside a nested dictionary"""
        for key, value in d.items():
            if key == "SessionStatus":
                return value
            if isinstance(value, dict):
                return self._get_session_status(value)

    async def _process_race_control_messages(self, msg):
        """
        Processes data from https://livetiming.formula1.com/static/.../RaceControlMessages.jsonStream

        The following information is present in the file:
            (1) All messages from Race Control (RCM)
                (a) Categories: "Other", "Drs", "Flag", "CarEvent", "SafetyCar"
        """

        msg = msg["Messages"]
        tasks = []

        # The first message sent might be a list sometimes, we can ignore that
        if isinstance(msg, dict):
            for messageNum in msg:
                data = msg[messageNum]
                timestamp = self._convert_to_timestamp(data["Utc"])

                if data["Category"] == "Other":
                    tasks.append(
                        self._redis.hset(
                            name="RaceControlMessages",
                            key=messageNum,
                            value=f'Other,{data["Message"]}::{timestamp}',
                        )
                    )

                    tasks.append(
                        self._kafka.send(
                            topic="RCM",
                            key="Other",
                            value=f'{data["Message"]}::{timestamp}',
                        )
                    )

                    # Handling deleted lap times
                    if "DELETED" in data["Message"]:
                        driver = ""
                        lap = ""

                        # Find which drivers lap time was deleted
                        msgParts = data["Message"].split("CAR")
                        for item in msgParts:
                            for char in item.strip():
                                if char.isdigit():
                                    driver += char
                                else:
                                    break
                        # Find which lap number was deleted
                        msgParts = data["Message"].split("LAP")
                        for item in msgParts:
                            for char in item.strip():
                                if char.isdigit():
                                    lap += char
                                else:
                                    break

                        if (driver != "") and (lap != ""):
                            tasks.append(
                                self._redis.hset(
                                    name=f"{driver}:{lap}",
                                    key="Deleted",
                                    value=timestamp,
                                )
                            )

                            tasks.append(
                                self._kafka.send(
                                    topic="DeletedLaps",
                                    key=driver,
                                    value=f"{lap}::{timestamp}",
                                )
                            )

                elif data["Category"] == "Drs":
                    tasks.append(
                        self._redis.hset(
                            name="RaceControlMessages",
                            key=messageNum,
                            value=f'Drs,{data["Status"]}::{timestamp}',
                        )
                    )

                    tasks.append(
                        self._kafka.send(
                            topic="RCM",
                            key="DRS",
                            value=f'{data["Status"]}::{timestamp}',
                        )
                    )

                elif data["Category"] == "Flag":
                    tasks.append(
                        self._redis.hset(
                            name="RaceControlMessages",
                            key=messageNum,
                            value=f'Flag,{data["Flag"]},{data["Scope"]},{data["Message"]}::{timestamp}',
                        )
                    )

                    tasks.append(
                        self._kafka.send(
                            topic="RCM",
                            key="Flag",
                            value=f'{data["Flag"]},{data["Scope"]},{data["Message"]}::{timestamp}',
                        )
                    )

                elif data["Category"] == "SafetyCar":
                    tasks.append(
                        self._redis.hset(
                            name="RaceControlMessages",
                            key=messageNum,
                            value=f'SafetyCar,{data["Mode"]},{data["Status"]},{data["Message"]}::{timestamp}',
                        )
                    )

                    tasks.append(
                        self._kafka.send(
                            topic="RCM",
                            key="SafetyCar",
                            value=f'{data["Mode"]},{data["Status"]},{data["Message"]}::{timestamp}',
                        )
                    )

                elif data["Category"] == "CarEvent":
                    tasks.append(
                        self._redis.hset(
                            name="RaceControlMessages",
                            key=messageNum,
                            value=f'CarEvent,{data["RacingNumber"]},{data["Message"]}::{timestamp}',
                        )
                    )

                    tasks.append(
                        self._kafka.send(
                            topic="RCM",
                            key="CarEvent",
                            value=f'{data["RacingNumber"]},{data["Message"]}::{timestamp}',
                        )
                    )

        await asyncio.gather(*tasks)

    async def _process_car_data(self, msg):
        """
        Processes data from https://livetiming.formula1.com/static/.../CarData.z.jsonStream

        The following information is present in the file: (Sourced from Fast-F1, 240ms sample rate)
            - Speed (int): Km/h
            - RPM (int)
            - Gear (int): [called 'nGear' in the data!]
            - Throttle (int): 0-100%
            - Brake (bool)
            - DRS (int): 0-14 (Odd DRS is Disabled, Even DRS is Enabled?)
              (More Research Needed?)
              - 0 =  Off
              - 1 =  Off
              - 2 =  (?)
              - 3 =  (?)
              - 8 =  Detected, Eligible once in Activation Zone (Noted Sometimes)
              - 10 = On (Unknown Distinction)
              - 12 = On (Unknown Distinction)
              - 14 = On (Unknown Distinction)
        """
        # kafka stream uncompressed data

        msg = zlib.decompress(base64.b64decode(msg), -zlib.MAX_WBITS).decode()
        msg = ujson.loads(msg)["Entries"]

        tasks = []

        for item in msg:
            timestamp = self._convert_to_timestamp(item["Utc"])

            data = item["Cars"]

            for driver in data:
                # If driver has retired, we can ignore any car data
                if driver in self.retiredDrivers:
                    continue

                curLap = await self._redis.hget(name=driver, key="CurrentLap")
                if curLap is None:
                    curLap = 1
                    lapStartTime = 0
                else:
                    temp = curLap.split("::")
                    curLap = int(temp[0])
                    lapStartTime = float(temp[1])

                if timestamp < lapStartTime:
                    curLap -= 1

                temp = data[driver]["Channels"]
                res = f'{temp["0"]},{temp["2"]},{temp["3"]},{temp["4"]},{temp["5"]},{temp["45"]}'

                tasks.append(
                    self._redis.hset(
                        name=f"{driver}:{curLap}:CarData",
                        key=timestamp,
                        value=res,
                    )
                )

                tasks.append(
                    self._kafka.send(
                        topic="CarData",
                        key=driver,
                        value=f"{res};;{curLap}::{timestamp}",
                    )
                )

        await asyncio.gather(*tasks)

    async def _process_position_data(self, msg):
        """
        Processes data from https://livetiming.formula1.com/static/.../Position.z.jsonStream

        The following information is present in the file: (Sourced from Fast-F1, 220ms sample rate)
            - Status (str): 'OnTrack' or 'OffTrack'
            - X, Y, Z (int): Position coordinates; starting from 2020 the coordinates are given in 1/10 meter
        """
        # kafka stream uncompressed dat

        msg = zlib.decompress(base64.b64decode(msg), -zlib.MAX_WBITS).decode()
        msg = ujson.loads(msg)["Position"]

        tasks = []

        for item in msg:
            timestamp = self._convert_to_timestamp(item["Timestamp"])

            data = item["Entries"]

            for driver in data:
                # If driver has retired, we can ignore any position data
                if driver in self.retiredDrivers:
                    continue

                curLap = await self._redis.hget(name=driver, key="CurrentLap")
                if curLap is None:
                    curLap = 1
                    lapStartTime = 0
                else:
                    temp = curLap.split("::")
                    curLap = int(temp[0])
                    lapStartTime = float(temp[1])

                if timestamp < lapStartTime:
                    curLap -= 1

                res = f'{data[driver]["Status"]},{data[driver]["X"]},{data[driver]["Y"]},{data[driver]["Z"]}'

                tasks.append(
                    self._redis.hset(
                        name=f"{driver}:{curLap}:PositionData",
                        key=timestamp,
                        value=res,
                    )
                )

                tasks.append(
                    self._kafka.send(
                        topic="PositionData",
                        key=driver,
                        value=f"{res};;{curLap}::{timestamp}",
                    )
                )

        await asyncio.gather(*tasks)

    async def _process_driver_race_info(self, msg, timestamp):
        """
        Processes data from https://livetiming.formula1.com/static/.../DriverRaceInfo.jsonStream

        The following information is present in the file:
            (1) Overtakes for position during the race
            (2) If a driver has retired from the race
        """

        tasks = []
        for driver in msg:
            if "OvertakeState" in msg[driver]:
                if "Position" in msg[driver]:
                    tasks.append(
                        self._redis.hset(
                            name=driver,
                            key="Position",
                            value=f'{msg[driver]["Position"]}::{timestamp}',
                        )
                    )

                    tasks.append(
                        self._kafka.send(
                            topic="Position",
                            key=driver,
                            value=f'{msg[driver]["Position"]}::{timestamp}',
                        )
                    )

            if "IsOut" in msg[driver]:
                if msg[driver]["IsOut"] is True:
                    tasks.append(
                        self._redis.hset(name=driver, key="Retired", value=timestamp)
                    )
                    tasks.append(
                        self._kafka.send(topic="Retired", key=driver, value=timestamp)
                    )
                    self.retiredDrivers.add(driver)

        asyncio.gather(*tasks)

    async def process(self, topic, msg, timestamp):
        timestamp = self._convert_to_timestamp(timestamp)

        if (self.sessionStatus is None) or (self.sessionStatus == "Aborted"):
            if topic == "SessionData":
                await self._process_session_data(msg, timestamp)
            elif topic == "RaceControlMessages":
                await self._process_race_control_messages(msg)
            return

        if topic == "CarData.z":
            await self._process_car_data(msg)
        elif topic == "Position.z":
            await self._process_position_data(msg)
        elif topic == "TimingAppData":
            await self._process_timing_app_data(msg, timestamp)
        elif topic == "TimingData":
            await self._process_timing_data(msg, timestamp)
        elif topic == "LapCount":
            await self._process_lap_count(msg, timestamp)
        elif topic == "RaceControlMessages":
            await self._process_race_control_messages(msg)
        elif topic == "SessionData":
            await self._process_session_data(msg, timestamp)
        elif topic == "DriverRaceInfo":
            await self._process_driver_race_info(msg, timestamp)


import ast
import time
import statistics
import datetime
import traceback

starting_pos = [
    16,
    1,
    11,
    55,
    44,
    14,
    4,
    22,
    18,
    81,
    63,
    23,
    77,
    2,
    24,
    20,
    10,
    21,
    31,
    27,
]

timings = []


async def test():
    Processor = ProcessLiveData(startingPositions=starting_pos)
    await Processor.start()

    fileH = open("jsonStreams/Race/saved_data.txt", "r")

    for i, line in enumerate(fileH):
        line = line.strip()
        msg = ast.literal_eval(line)

        try:
            # if i != 0 and Processor.sessionStatus == "Started":
            #     time.sleep(
            #         (
            #             datetime.datetime.strptime(msg[2][:-2], "%Y-%m-%dT%H:%M:%S.%f")
            #             - prevTime
            #         ).total_seconds()
            #         / 100
            #     )

            start = time.time()
            await Processor.process(topic=msg[0], msg=msg[1], timestamp=msg[2])
            end = time.time()
            timings.append((end - start) * 100)
            # print(f"{(end - start)*100:.10f}ms")
        except Exception as e:
            print(traceback.format_exc())
            print(f"\nData : {line}\nException : {e}\n")

        # try:
        #    prevTime = datetime.datetime.strptime(msg[2][:-2], "%Y-%m-%dT%H:%M:%S.%f")
        # except:
        #     pass

    fileH.close()
    await Processor.stop()


asyncio.run(test())

print(
    f"Median: {statistics.median(timings):.10f}ms\nMean: {statistics.mean(timings):.10f}ms\nStdDev: {statistics.pstdev(timings)}\n"
)
print(
    f"1st percentile: {statistics.quantiles(timings, n=100)[0]}\n5th percentile: {statistics.quantiles(timings, n=100)[4]}\n95th percentile: {statistics.quantiles(timings, n=100)[94]}\n99th percentile: {statistics.quantiles(timings, n=100)[98]}"
)
