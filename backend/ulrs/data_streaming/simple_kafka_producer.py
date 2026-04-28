from kafka import KafkaProducer
import json
import time

producer = KafkaProducer(
    bootstrap_servers='localhost:9092',
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

for i in range(10):
    message = {"id": i, "message": f"Hello Kafka! Message #{i}"}
    print(f"Sending: {message}")
    
    producer.send('my-topic', value=message)
    time.sleep(1)

producer.flush()
producer.close()
print("Producer done.")