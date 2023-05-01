from aiokafka import AIOKafkaConsumer
import asyncio


topics = [
    "TyreAge",
    "LapTime",
    "CurrentLap",
    "Tyre",
    "GapToLeader",
    "IntervalToPositionAhead",
    "SectorTime",
    "Speed",
    "InPit",
    "NumberOfPitStops",
    "PitOut",
    "CarData",
    "PositionData",
    "Position",
    "Retired",
    "TotalLaps",
    "LapCount",
    "SessionStatus",
    "RCM",
]


def deserializer(value) -> str:
    return value.decode()


async def consume():
    consumer = AIOKafkaConsumer(
        *topics,
        bootstrap_servers="localhost:9092",
        group_id="my-group",
        key_deserializer=deserializer,
        value_deserializer=deserializer,
        connections_max_idle_ms=1000
    )
    # Get cluster layout and join group `my-group`
    await consumer.start()
    try:
        # Consume messages
        async for msg in consumer:
            print(
                "consumed: ",
                msg.topic,
                msg.partition,
                msg.offset,
                msg.key,
                msg.value,
                msg.timestamp,
            )
    finally:
        # Will leave consumer group; perform autocommit if enabled.
        await consumer.stop()


asyncio.run(consume())
