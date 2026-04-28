from kafka import KafkaProducer
import json
import time

# Initialize the producer
producer = KafkaProducer(
    bootstrap_servers='localhost:9092',
    value_serializer=lambda v: json.dumps(v).encode('utf-8')  # serialize to JSON bytes
)

# Send 10 messages
for i in range(10):
    message = {"id": i, "message": f"Hello Kafka! Message #{i}"}
    print(f"Sending: {message}")
    
    producer.send('my-topic', value=message)
    time.sleep(1)  # 1 second between messages

# Block until all messages are sent
producer.flush()
producer.close()
print("Producer done.")