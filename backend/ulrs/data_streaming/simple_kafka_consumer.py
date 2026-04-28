from kafka import KafkaConsumer
import json

# Initialize the consumer
consumer = KafkaConsumer(
    'my-topic',
    bootstrap_servers='localhost:9092',
    auto_offset_reset='earliest',
    enable_auto_commit=True,
    group_id='my-consumer-group',
    value_deserializer=lambda v: json.loads(v.decode('utf-8'))
)

print("Listening for messages...")

for message in consumer:
    print(f"Received | Topic: {message.topic} | "
          f"Partition: {message.partition} | "
          f"Offset: {message.offset} | "
          f"Value: {message.value}")