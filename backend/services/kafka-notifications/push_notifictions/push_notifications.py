from kafka import KafkaConsumer
from openai import OpenAI
import json
import os

NOTIFICATIONS_TOPIC = 'notifications'
KAFKA_BOOTSTRAP_SERVERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')

consumer = KafkaConsumer(
    NOTIFICATIONS_TOPIC,
    bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
    auto_offset_reset='earliest',
    enable_auto_commit=False,
    group_id='push_notifications',
    value_deserializer=lambda v: json.loads(v.decode('utf-8'))
)

ai_client = OpenAI()


def send_push_notification(news_event):
    '''
    TODO: implement push notification for news events
    1. Get all users associated with symbol
    2. Send all users news event if sentiment is not neutral
    '''


for message in consumer:
    send_push_notification(message.value)
    consumer.commit()