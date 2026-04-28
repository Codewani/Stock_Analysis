from kafka import KafkaConsumer
import json

consumer = KafkaConsumer(
    'my-topic',
    bootstrap_servers='localhost:9092',
    auto_offset_reset='earliest',
    enable_auto_commit=True,
    group_id='my-consumer-group',
    value_deserializer=lambda v: json.loads(v.decode('utf-8'))
)


def send_push_notification(news_event):
    '''
    TODO: implement push notifications after ai evaluation
    '''
    pass

for message in consumer:
    send_push_notification(message)