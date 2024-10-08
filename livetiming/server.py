import asyncio
import uvloop
from livetiming.fastf1_livetiming.signalrc_client import SignalRClient
from livetiming.process_livedata import ProcessLiveData

asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())

topics = [
    "Heartbeat",
    "CarData.z",
    "Position.z",
    "TimingStats",
    "TimingAppData",
    "WeatherData",
    "TrackStatus",
    "DriverList",
    "RaceControlMessages",
    "SessionInfo",
    "SessionData",
    "LapCount",
    "TimingData",
    "CurrentTyres",
    "TeamRadio",
    "LapSeries",
    "SPFeed",
    "ChampionshipPrediction",
    "DriverRaceInfo",
]


async def start():
    client = SignalRClient(topics=topics, processor=ProcessLiveData(), timeout=60)
    await client.start()


asyncio.run(start())
