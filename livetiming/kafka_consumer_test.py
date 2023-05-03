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
        group_id=None,
        key_deserializer=deserializer,
        value_deserializer=deserializer,
        consumer_timeout_ms=2000,
        auto_offset_reset="earliest"
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
