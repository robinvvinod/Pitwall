import ujson
import redis.asyncio as redis
import aiokafka
import asyncio


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

    def __init__(self, redis_url="localhost", kafka_url="localhost:9092"):
        self._redis = redis.Redis(host=redis_url, decode_responses=True)
        self._kafka = aiokafka.AIOKafkaProducer(bootstrap_servers=kafka_url)

        self.sessionStatus = None

    async def start_kafka_producer(self):
        await self._kafka.start()

    async def stop_kafka_producer(self):
        await self._kafka.stop()

    async def _get_current_lap(self, driver) -> str:
        """Get current lap any driver is on"""
        curLap = await self._redis.hget(name=driver, key="CurrentLap")
        if curLap is None:
            curLap = "1"
        return curLap

    async def _process_timing_app_data(self, msg):
        """
        Processes data from https://livetiming.formula1.com/static/.../TimingAppData.jsonStream

        The following information is present in the file:
            (1) TotaLaps done on a certain tyre
            (2) Stint Number
            (3) LapTime of a given LapNumber
            (4) Compound type of tyre changed in pitstop
                (a) Age of tyres fitted in pitstop
        """

        receivedData = ujson.loads(msg[12:])["Lines"]
        tasks = []

        # receivedData may contain information for more than 1 driver, where driver no. is the key
        for driver in receivedData:
            # Filter out noise. All important information is under key "Stints"
            if "Stints" in receivedData[driver]:
                # During a race, the first message sent has no Stint number as the race hasn't started yet
                # The first message is a dict wrapped in a list to indicate the starting tyres
                if isinstance(receivedData[driver]["Stints"], list):
                    curStint = "0"
                    indvData = receivedData[driver]["Stints"][0]
                else:
                    # receivedData[driver]["Stints"] is a dict containing only 1 key
                    curStint = next(
                        iter(receivedData[driver]["Stints"])
                    )  # Find key in O(1)
                    indvData = receivedData[driver]["Stints"][curStint]

                # TotalLaps is the number of laps driven on current set of tyres
                # Includes laps driven on other sessions

                if "TotalLaps" in indvData:
                    curLap = await self._get_current_lap(driver)
                    tasks.append(
                        self._redis.hset(
                            name=f"{driver}:{curLap}",
                            mapping={
                                "TyreAge": indvData["TotalLaps"],
                                "StintNumber": curStint,
                            },
                        )
                    )

                    tasks.append(
                        self._kafka.send(
                            topic="TyreAge",
                            value=str(indvData["TotalLaps"]).encode(),
                            key=driver.encode(),
                        )
                    )

                if ("LapTime" in indvData) and ("LapNumber" in indvData):
                    tasks.append(
                        self._redis.hset(
                            name=f'{driver}:{indvData["LapNumber"]}',
                            key="LapTime",
                            value=f'{indvData["LapTime"]}',
                        )
                    )

                    tasks.append(
                        self._kafka.send(
                            topic="LapTime",
                            key=driver.encode(),
                            value=f'{indvData["LapTime"]},indvData["LapNumber"]'.encode(),
                        )
                    )

                    tasks.append(
                        self._redis.hset(
                            name=driver,
                            key="CurrentLap",
                            value=int(indvData["LapNumber"]) + 1,
                        )
                    )

                    tasks.append(
                        self._kafka.send(
                            topic="CurrentLap",
                            key=driver.encode(),
                            value=f'{int(indvData["LapNumber"])+1}'.encode(),
                        )
                    )

                if ("Compound" in indvData) and (indvData["Compound"] != "UNKNOWN"):
                    curLap = await self._get_current_lap(driver)
                    mapping = {
                        "TyreType": f'{indvData["Compound"]}',
                        "StintNumber": curStint,
                    }

                    # On the event that a cars pitbox is before the start/finish line,
                    # the new tyre is fitted in the current lap, although it should only
                    # be counted as having been fitted from the next lap onward
                    if await self._redis.hexists(
                        name=f"{driver}:{curLap}", key="PitIn"
                    ):
                        curLap = int(curLap) + 1

                    tasks.append(
                        self._redis.hset(
                            name=f"{driver}:{curLap}",
                            mapping=mapping,
                        )
                    )

                    tasks.append(
                        self._kafka.send(
                            topic="Tyre",
                            key=driver.encode(),
                            value=f'{indvData["Compound"]},{curStint}'.encode(),
                        )
                    )

        await asyncio.gather(*tasks)

    async def _process_timing_data(self, msg):
        """
        Processes data from https://livetiming.formula1.com/static/.../TimingData.jsonStream

        The following information is present in the file:
            (1) GapToLeader (Stream)
            (2) IntervalToPositionAhead (Stream)
            (3) Individual sector time
            (4) Speed trap speed
            (5) Pit stop entry and exit
        """

        # Seperate the timestamp from the JSON data
        timestamp = msg[:12]  # HH:MM:SS.MLS
        receivedData = ujson.loads(msg[12:])["Lines"]
        tasks = []

        # receivedData may contain information for more than 1 driver, where driver no. is the key
        for driver in receivedData:
            if "GapToLeader" in receivedData[driver]:
                # TODO: Calculate gap to leader at the end of a lap
                pass

            if "IntervalToPositionAhead" in receivedData[driver]:
                # broadcast gap to position ahead
                pass

            if ("Sectors" in receivedData[driver]) and (
                isinstance(receivedData[driver]["Sectors"], dict)
            ):
                for indvSector in receivedData[driver]["Sectors"]:
                    if "Value" in receivedData[driver]["Sectors"][indvSector]:
                        curLap = await self._get_current_lap(driver)
                        sectorNumber = int(indvSector) + 1
                        sectorTime = receivedData[driver]["Sectors"][indvSector][
                            "Value"
                        ]

                        # Sometimes "Value" is empty due to poor formatting in the livedata
                        if sectorTime != "":
                            tasks.append(
                                self._redis.hset(
                                    name=f"{driver}:{curLap}",
                                    key=f"Sector{sectorNumber}Time",
                                    value=sectorTime,
                                )
                            )

                        # TODO: Process personal/overall fastest sectors
                        # TODO: Handle contingency if sector 3 time arrives after new lap signal

            if "Speeds" in receivedData[driver]:
                for indvSpeed in receivedData[driver]["Speeds"]:
                    speedTrap = receivedData[driver]["Speeds"][indvSpeed]
                    curLap = await self._get_current_lap(driver)

                    if ("Value" in speedTrap) and (speedTrap["Value"] != ""):
                        if indvSpeed == "I1":
                            mapping = {"Sector1SpeedTrap": speedTrap["Value"]}
                        elif indvSpeed == "I2":
                            mapping = {"Sector2SpeedTrap": speedTrap["Value"]}
                        elif indvSpeed == "FL":
                            mapping = {"FinishLineSpeedTrap": speedTrap["Value"]}
                        elif indvSpeed == "ST":
                            mapping = {"BackStraightSpeedTrap": speedTrap["Value"]}

                        tasks.append(
                            self._redis.hset(
                                name=f"{driver}:{curLap}",
                                mapping=mapping,
                            )
                        )

                    # TODO: Process personal/fastest speeds on speed traps

            if "InPit" in receivedData[driver]:
                if (receivedData[driver]["InPit"] == "true") and (
                    "NumberOfPitStops" in receivedData[driver]
                ):
                    # Driver just entered pit
                    curLap = await self._get_current_lap(driver)
                    tasks.append(
                        self._redis.hset(
                            name=driver,
                            key="NumberOfPitStops",
                            value=receivedData[driver]["NumberOfPitStops"],
                        )
                    )

                    tasks.append(
                        self._redis.hset(
                            name=f"{driver}:{curLap}", key="PitIn", value=True
                        )
                    )
                elif (receivedData[driver]["InPit"] == "false") and (
                    "PitOut" in receivedData[driver]
                ):
                    # Driver just exited pit
                    curLap = await self._get_current_lap(driver)
                    tasks.append(
                        self._redis.hset(
                            name=f"{driver}:{curLap}", key="PitOut", value=True
                        )
                    )

                else:
                    # if InPit == false and PitOut is not present, driver left pit for first time
                    pass

                # TODO: Use timestamps to determine pit stop time

        await asyncio.gather(*tasks)

    async def _process_lap_count(self, msg):
        """
        Processes data from https://livetiming.formula1.com/static/.../LapCount.jsonStream

        The following information is present in the file:
            (1) Current lap of race, set by race leader
            (2) Total laps in race
        """

        # Seperate the timestamp from the JSON data
        timestamp = msg[:12]  # HH:MM:SS.MLS
        receivedData = ujson.loads(msg[12:])
        tasks = []

        if "TotalLaps" in receivedData:  # CurrentLap == 1
            # CurrentLap may be = 1 although session has not started yet
            # Check SessionData.jsonStream for cue to start of session
            tasks.append(
                self._redis.hset(
                    name="Session", key="TotalLaps", value=receivedData["TotalLaps"]
                )
            )

        tasks.append(
            self._redis.hset(
                name="Session", key="CurrentLap", value=receivedData["CurrentLap"]
            )
        )

        await asyncio.gather(*tasks)

    async def _process_session_data(self, msg):
        """
        Processes data from https://livetiming.formula1.com/static/.../SessionData.jsonStream

        The following information is present in the file:
            (1) Session start time
            (2) Session end time
        """

        # Seperate the timestamp from the JSON data
        timestamp = msg[:12]  # HH:MM:SS.MLS
        receivedData = ujson.loads(msg[12:])
        tasks = []

        if self._get_session_status(receivedData) == "Started":
            self.sessionStatus = "Started"
            tasks.append(
                self._redis.hset(name="Session", key="StartTime", value=timestamp)
            )
        elif self._get_session_status(receivedData) == "Finished":
            self.sessionStatus = "Finished"
            tasks.append(
                self._redis.hset(name="Session", key="EndTime", value=timestamp)
            )

        await asyncio.gather(*tasks)

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

        # Seperate the timestamp from the JSON data
        timestamp = msg[:12]  # HH:MM:SS.MLS
        receivedData = ujson.loads(msg[12:])["Messages"]
        tasks = []

        # The first message sent might be a list sometimes, we can ignore that
        if isinstance(receivedData, dict):
            for messageNum in receivedData:
                data = receivedData[messageNum]
                utc = data["Utc"]

                # Practice and Quali RCMs are not associated with a particular laps
                if "Lap" in data:
                    res = "," + str(data["Lap"])
                else:
                    res = ""

                if data["Category"] == "Other":
                    tasks.append(
                        self._redis.hset(
                            name="RaceControlMessages",
                            key=messageNum,
                            value=f'Other,{utc},{data["Message"]}{res}',
                        )
                    )

                elif data["Category"] == "Drs":
                    tasks.append(
                        self._redis.hset(
                            name="RaceControlMessages",
                            key=messageNum,
                            value=f'Drs,{utc},{data["Status"]}{res}',
                        )
                    )

                elif data["Category"] == "Flag":
                    tasks.append(
                        self._redis.hset(
                            name="RaceControlMessages",
                            key=messageNum,
                            value=f'Flag,{utc},{data["Flag"]},{data["Scope"]},{data["Message"]}{res}',
                        )
                    )

                elif data["Category"] == "SafetyCar":
                    tasks.append(
                        self._redis.hset(
                            name="RaceControlMessages",
                            key=messageNum,
                            value=f'SafetyCar,{utc},{data["Mode"]},{data["Status"]},{data["Message"]}{res}',
                        )
                    )

                elif data["Category"] == "CarEvent":
                    tasks.append(
                        self._redis.hset(
                            name="RaceControlMessages",
                            key=messageNum,
                            value=f'CarEvent,{utc},{data["RacingNumber"]},{data["Message"]}{res}',
                        )
                    )

        await asyncio.gather(*tasks)

    async def process(self, msg, topic):
        # if topic == "TimingAppData":
        #    _process_timing_app_data(msg)
        pass


async def test():
    Processor = ProcessLiveData()
    await Processor.start_kafka_producer()
    fileH = open("jsonStreams/TimingData.jsonStream", "r", encoding="utf-8-sig")

    for line in fileH:
        await Processor._process_timing_data(line)

    fileH.close()
    await Processor.stop_kafka_producer()


asyncio.run(test())
