import asyncio

from livetiming.fastf1_livetiming.signalrc_client import SignalRClient
from livetiming.process_livedata import ProcessLiveData

topics = [
    "Heartbeat",
    "CarData.z",
    "Position.z",
    "ExtrapolatedClock",
    "TopThree",
    "RcmSeries",
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
]

client = SignalRClient(topics=topics, processor=ProcessLiveData(), timeout=0)

asyncio.run(client.start())
