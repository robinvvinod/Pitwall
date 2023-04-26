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

    async def _get_current_lap(self, driver):
        """Get current lap any driver is on"""
        curLap = await self._redis.hget(name=driver, key="CurrentLap")
        if curLap is None:
            curLap = 1
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
                for curStint in receivedData[driver]["Stints"]:
                    # Sometimes curStint is a list due to poor formatting in the livedata.
                    if isinstance(curStint, str):
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
                                self._kafka.send_and_wait(
                                    "TyreAge", str(indvData["TotalLaps"]).encode()
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
                                self._redis.hset(
                                    name=driver,
                                    key="CurrentLap",
                                    value=int(indvData["LapNumber"]) + 1,
                                )
                            )

                        if ("Compound" in indvData) and (
                            indvData["Compound"] != "UNKNOWN"
                        ):
                            curLap = await self._get_current_lap(driver)
                            mapping = {
                                "TyreType": f'{indvData["Compound"]}',
                                "StintNumber": curStint,
                            }

                            if "TotalLaps" in indvData:
                                mapping["TyreAge"] = f'{indvData["TotalLaps"]}'

                            tasks.append(
                                self._redis.hset(
                                    name=f"{driver}:{int(curLap) + 1}",
                                    mapping=mapping,
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
                # broadcast gap to leader
                pass

            if "IntervalToPositionAhead" in receivedData[driver]:
                # broadcast gap to position ahead
                pass

            if "Sectors" in receivedData[driver]:
                for indvSector in receivedData[driver]["Sectors"]:
                    # Sometimes indvSector is a list due to poor formatting in the livedata.
                    if isinstance(indvSector, str):
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
                    # Sometimes indvSpeed is a list due to poor formatting in the livedata.
                    if isinstance(indvSpeed, str):
                        speedTrap = receivedData[driver]["Speeds"]
                        curLap = await self._get_current_lap(driver)

                        # Sometimes SpeedTrap["IX"]["Value"] is empty due to poor livedata
                        try:
                            if "I1" in speedTrap:
                                mapping = {"Sector1SpeedTrap": speedTrap["I1"]["Value"]}
                            elif "I2" in speedTrap:
                                mapping = {"Sector2SpeedTrap": speedTrap["I2"]["Value"]}
                            elif "FL" in speedTrap:
                                mapping = {
                                    "FinishLineSpeedTrap": speedTrap["FL"]["Value"]
                                }
                            elif "ST" in speedTrap:
                                mapping = {
                                    "BackStraightSpeedTrap": speedTrap["ST"]["Value"]
                                }

                            tasks.append(
                                self._redis.hset(
                                    name=f"{driver}:{curLap}",
                                    mapping=mapping,
                                )
                            )
                        except:
                            pass

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
                    name="race", key="TotalLaps", value=receivedData["TotalLaps"]
                )
            )

        tasks.append(
            self._redis.hset(
                name="race", key="CurrentLap", value=receivedData["CurrentLap"]
            )
        )

        asyncio.gather(*tasks)

    async def start_kafka_producer(self):
        await self._kafka.start()

    async def stop_kafka_producer(self):
        await self._kafka.stop()

    async def process(self, msg, topic):
        # if topic == "TimingAppData":
        #    _process_timing_app_data(msg)
        pass


async def test():
    Processor = ProcessLiveData()
    await Processor.start_kafka_producer()
    fileH = open("jsonStreams/TimingAppData.jsonStream", "r", encoding="utf-8-sig")

    for line in fileH:
        await Processor._process_timing_app_data(line)

    fileH.close()
    await Processor.stop_kafka_producer()


asyncio.run(test())
