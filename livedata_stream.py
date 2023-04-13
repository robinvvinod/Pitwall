import json

def process_timing_app_data(msg):
    
    # Seperate the timestamp from the JSON data
    timestamp = msg[:12] # HH:MM:SS.MLS
    receivedData = json.loads(msg[12:])["Lines"]
    
    # receivedData may contain information for more than 1 driver, where driver no. is the key
    for driver in receivedData:
        
        # "in" checks for <class 'dict'> is O(1)
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


fileH = open("jsonStreams/TimingAppData.jsonStream", "r", encoding="utf-8-sig")
for line in fileH:
   process_timing_app_data(line)
   

    

