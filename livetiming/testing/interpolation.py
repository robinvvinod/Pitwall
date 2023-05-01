import base64
import zlib
import ast
import datetime
import ujson
import time

positionData = []
carData = []


def start():
    fileH = open("../jsonStreams/Practice/saved_data.txt", "r")
    for line in fileH:
        line = line.strip()
        msg = ast.literal_eval(line)

        try:
            if msg[0] == "Position.z":
                text = zlib.decompress(
                    base64.b64decode(msg[1]), -zlib.MAX_WBITS
                ).decode()
                text = ujson.loads(text)
                positionData.append([msg[2], text])
            elif msg[0] == "CarData.z":
                text = zlib.decompress(
                    base64.b64decode(msg[1]), -zlib.MAX_WBITS
                ).decode()
                text = ujson.loads(text)
                carData.append([msg[2], text])

        except:
            pass

    fileH.close()


start()

for i, indvCarData in enumerate(carData):
    timestampC = indvCarData[0]
    indvCarData = indvCarData[1]
    indvCarData = indvCarData["Entries"]
    utcCarData = indvCarData[0]["Utc"]
    utcCarData = datetime.datetime.strptime(utcCarData[:-2], "%Y-%m-%dT%H:%M:%S.%f")

    timestampP = positionData[i][0]
    indvPositionData = positionData[i][1]["Position"]
    utcPositionData = indvPositionData[0]["Timestamp"]
    utcPositionData = datetime.datetime.strptime(
        utcPositionData[:-2], "%Y-%m-%dT%H:%M:%S.%f"
    )

    print(
        f'CarData {utcCarData.strftime("%H:%M:%S.%f")} PositionData {utcPositionData.strftime("%H:%M:%S.%f")}'
    )

print(len(positionData), len(carData))
