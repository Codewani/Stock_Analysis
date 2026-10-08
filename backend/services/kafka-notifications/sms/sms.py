from kafka import KafkaConsumer
import json
import os

NOTIFICATIONS_TOPIC = 'notifications'
KAFKA_BOOTSTRAP_SERVERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')


consumer = KafkaConsumer(
	NOTIFICATIONS_TOPIC,
	bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
	auto_offset_reset='earliest',
	enable_auto_commit=False,
	group_id='sms_notifications',
	value_deserializer=lambda v: json.loads(v.decode('utf-8'))
)


def send_sms_notification(news_event):
	'''
	TODO: implement SMS notification for news events
	1. Get all users subscribed to SMS notifications for matching symbols.
	2. Send the SMS when the news event meets notification criteria.
	'''


for message in consumer:
	send_sms_notification(message.value)
	consumer.commit()
