import ujson
import redis.asyncio as redis


class ProcessLiveData:
    def __init__(self, connection_url="localhost"):
        self._connection = redis.Redis(host=connection_url, encoding="utf8")

    def process_timing_app_data(self, msg):
        # Seperate the timestamp from the JSON data
        timestamp = msg[:12]  # HH:MM:SS.MLS
        receivedData = ujson.loads(msg[12:])["Lines"]

        # receivedData may contain information for more than 1 driver, where driver no. is the key
        for driver in receivedData:
            if "Stints" in receivedData[driver]:
                for curStint in receivedData[driver]["Stints"]:
                    # Sometimes curStint is a list due to poor formatting in the livedata. We are only interested in curStint as the stint number of the car.
                    if isinstance(curStint, str):
                        if "TotalLaps" in receivedData[driver]["Stints"][curStint]:
                            # broadcast totalLaps done in tyres of current stint (incl in other sessions)
                            pass

                        if "LapTime" in receivedData[driver]["Stints"][curStint]:
                            # broadcast previous LapTime of (LapNumber - 1)th lap & LapNumber
                            pass

                        if "Compound" in receivedData[driver]["Stints"][curStint]:
                            # receivedData[driver]["Stints"][curStint]["Compound"] = SOFT/MEDIUM/HARD
                            # receivedData[driver]["Stints"][curStint]["New"] = true/false
                            # broadcast change in stintNumber as well
                            pass

    def process_timing_data(self, msg):
        # Seperate the timestamp from the JSON data
        timestamp = msg[:12]  # HH:MM:SS.MLS
        receivedData = ujson.loads(msg[12:])["Lines"]

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
                    # Sometimes indvSector is a list due to poor formatting in the livedate.
                    if isinstance(indvSector, str):
                        # Sector number = indvSector
                        if "Value" in receivedData[driver]["Sectors"][indvSector]:
                            # sectorTime = receivedData[driver]["Sectors"][indvSector]["Value"]
                            # broadcast
                            pass

            if "Speeds" in receivedData[driver]:
                for indvSpeed in receivedData[driver]["Speeds"]:
                    # Sometimes indvSpeed is a list due to poor formatting in the livedata.
                    if isinstance(indvSpeed, str):
                        # whichSector = int(indvSpeed) + 1
                        # speed = receivedData[driver]["Speeds"][indvSpeed]["Value"]
                        # broadcast
                        pass

            if "InPit" in receivedData[driver]:
                if receivedData[driver]["InPit"] == "true":
                    # Driver just entered pit
                    if "NumberOfPitStops" in receivedData[driver]:
                        # broadcast
                        pass
                elif (receivedData[driver]["InPit"] == "false") and (
                    "PitOut" in receivedData[driver]
                ):
                    # Driver just exited pit
                    pass
                else:
                    # if InPit == false and PitOut is not present, driver left pit for first time
                    pass

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


# fileH = open("jsonStreams/TimingData.jsonStream", "r", encoding="utf-8-sig")
# for line in fileH:
#     process_timing_data(line)
