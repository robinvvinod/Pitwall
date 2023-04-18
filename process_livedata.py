import ujson
import redis.asyncio as redis
import asyncio


class ProcessLiveData:
    """
    A client for processing live data captured by fastf1-livetiming.signalrc_client.py.

    Args:
        connection_url (str) : url of the redis data structure server where data is cached
        logger (Logger or None) : By default, errors are logged to the
            console. If you wish to customize logging, you can pass an
            instance of :class:`logging.Logger` (see: :mod:`logging`).
    """

    def __init__(self, connection_url="localhost"):
        self._connection = redis.Redis(host=connection_url, decode_responses=True)

    async def get_current_lap(self, driver):
        """Get current lap any driver is on"""
        curLap = await self._connection.hget(name=driver, key="CurrentLap")
        if curLap is None:
            curLap = 1
        return curLap

    async def process_timing_app_data(self, msg):
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
                            curLap = await self.get_current_lap(driver)
                            tasks.append(
                                self._connection.hset(
                                    name=f"{driver}:{curLap}",
                                    mapping={
                                        "TyreAge": indvData["TotalLaps"],
                                        "StintNumber": curStint,
                                    },
                                )
                            )

                        if ("LapTime" in indvData) and ("LapNumber" in indvData):
                            tasks.append(
                                self._connection.hset(
                                    name=f'{driver}:{indvData["LapNumber"]}',
                                    key="LapTime",
                                    value=f'{indvData["LapTime"]}',
                                )
                            )
                            tasks.append(
                                self._connection.hset(
                                    name=driver,
                                    key="CurrentLap",
                                    value=int(indvData["LapNumber"]) + 1,
                                )
                            )

                        if ("Compound" in indvData) and (
                            indvData["Compound"] != "UNKNOWN"
                        ):
                            curLap = await self.get_current_lap(driver)
                            mapping = {
                                "TyreType": f'{indvData["Compound"]}',
                                "StintNumber": curStint,
                            }

                            if "TotalLaps" in indvData:
                                mapping["TyreAge"] = f'{indvData["TotalLaps"]}'

                            tasks.append(
                                self._connection.hset(
                                    name=f"{driver}:{int(curLap) + 1}",
                                    mapping=mapping,
                                )
                            )

        await asyncio.gather(*tasks)

    async def process_timing_data(self, msg):
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
                            curLap = await self.get_current_lap(driver)
                            sectorNumber = int(indvSector) + 1
                            sectorTime = receivedData[driver]["Sectors"][indvSector][
                                "Value"
                            ]

                            # Sometimes "Value" is empty due to poor formatting in the livedata
                            if sectorTime != "":
                                tasks.append(
                                    self._connection.hset(
                                        name=f"{driver}:{curLap}",
                                        key=f"Sector{sectorNumber}Time",
                                        value=sectorTime,
                                    )
                                )

                            # TODO: Process personal/overall fastest sectors

            if "Speeds" in receivedData[driver]:
                for indvSpeed in receivedData[driver]["Speeds"]:
                    # Sometimes indvSpeed is a list due to poor formatting in the livedata.
                    if isinstance(indvSpeed, str):
                        speedTrap = receivedData[driver]["Speeds"]
                        curLap = await self.get_current_lap(driver)

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
                                self._connection.hset(
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
                    curLap = await self.get_current_lap(driver)
                    tasks.append(
                        self._connection.hset(
                            name=driver,
                            key="NumberOfPitStops",
                            value=receivedData[driver]["NumberOfPitStops"],
                        )
                    )

                    tasks.append(
                        self._connection.hset(
                            name=f"{driver}:{curLap}", key="PitIn", value=True
                        )
                    )
                elif (receivedData[driver]["InPit"] == "false") and (
                    "PitOut" in receivedData[driver]
                ):
                    # Driver just exited pit
                    curLap = await self.get_current_lap(driver)
                    tasks.append(
                        self._connection.hset(
                            name=f"{driver}:{curLap}", key="PitOut", value=True
                        )
                    )

                else:
                    # if InPit == false and PitOut is not present, driver left pit for first time
                    pass

        await asyncio.gather(*tasks)

    def process_lap_count(self, msg):
        # Seperate the timestamp from the JSON data
        timestamp = msg[:12]  # HH:MM:SS.MLS
        receivedData = ujson.loads(msg[12:])

        # broadcast receivedData["CurrentLap"]
        if "TotalLaps" in receivedData:  # CurrentLap == 1
            # broadcast receivedData["TotalLaps"]
            # CurrentLap = 1 although session has not started yet
            # Check SessionData.jsonStream for cue to start of session
            pass
        else:
            # broadcast receivedData["CurrentLap"]
            pass


async def test():
    Processor = ProcessLiveData()
    fileH = open("jsonStreams/TimingAppData.jsonStream", "r", encoding="utf-8-sig")

    for line in fileH:
        await Processor.process_timing_app_data(line)

    fileH.close()


asyncio.run(test())
