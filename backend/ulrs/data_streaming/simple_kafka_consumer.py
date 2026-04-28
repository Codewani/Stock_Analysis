from kafka import KafkaConsumer
import json

# Initialize the consumer
consumer = KafkaConsumer(
    'my-topic',
    bootstrap_servers='localhost:9092',
    auto_offset_reset='earliest',        # start from the beginning of the topic
    enable_auto_commit=True,             # auto-commit offsets
    group_id='my-consumer-group',        # consumer group ID
    value_deserializer=lambda v: json.loads(v.decode('utf-8'))  # deserialize from JSON bytes
)

print("Listening for messages...")

# Poll for messages indefinitely
for message in consumer:
    print(f"Received | Topic: {message.topic} | "
          f"Partition: {message.partition} | "
          f"Offset: {message.offset} | "
          f"Value: {message.value}")