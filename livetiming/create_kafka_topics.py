from kafka.admin import KafkaAdminClient, NewTopic

session_topics = ["TotalLaps", "LapCount", "SessionStatus", "RCM"]
driver_topics = [
    "CurrentLap",
    "NumberOfPitStops",
    "Position",
    "Retired",
    "Fastest",
    "TyreAge",
    "LapTime",
    "Tyre",
    "GapToLeader",
    "IntervalToPositionAhead",
    "SectorTime",
    "Speed",
    "PitIn",
    "PitOut",
    "CarData",
    "PositionData",
    "DeletedLaps",
]


def create_topics(client, topic_names, num_partitions=1):
    topic_list = []
    for topic in topic_names:
        print(f"Topic : {topic} added ")
        topic_list.append(
            NewTopic(name=topic, num_partitions=num_partitions, replication_factor=1)
        )
    try:
        client.create_topics(new_topics=topic_list, validate_only=False)
        print("Topics created successfully")
    except Exception as e:
        print(e)


def delete_topics(client, topic_names):
    try:
        client.delete_topics(topics=topic_names)
        print("Topic Deleted Successfully")
    except Exception as e:
        print(e)


client = KafkaAdminClient(bootstrap_servers="localhost:9092")
create_topics(client, session_topics, num_partitions=1)
create_topics(client, driver_topics, num_partitions=20)
