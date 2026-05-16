import json
import os
import resend
from backend.db.session import get_db
from backend.services.streaming import get_users_by_symbols
from dotenv import load_dotenv
from kafka import KafkaConsumer

load_dotenv()

resend.api_key = os.environ["RESEND_API_KEY"]

NOTIFICATIONS_TOPIC = 'notifications'


consumer = KafkaConsumer(
	NOTIFICATIONS_TOPIC,
	bootstrap_servers='localhost:9092',
	auto_offset_reset='earliest',
	enable_auto_commit=False,
	group_id='email_notifications',
	value_deserializer=lambda v: json.loads(v.decode('utf-8'))
)

def send_email_notification(news_event):
	db_generator = get_db()
	db = next(db_generator)
	try:
		users = get_users_by_symbols(news_event["symbols"], db)
		for user in users:
			try:
				result = resend.Emails.send({
					"from": os.environ.get("EMAIL_FROM", f"Acme <alerts@notifications.codewani.com>"),
					"to": [user.email],
					"subject": f"Stock alert: {', '.join(news_event['symbols'])}",
					"html": (
						f"<h1>{news_event['headline']}</h1>"
						f"<p>{news_event['summary']}</p>"
						f"<p>Sentiment: {news_event['sentiment']}</p>"
						f"<p><a href=\"{news_event['url']}\">Read more</a></p>"
					),
					"text": (
						f"{news_event['headline']}\n\n"
						f"{news_event['summary']}\n\n"
						f"Sentiment: {news_event['sentiment']}\n"
						f"Read more: {news_event['url']}"
					),
				})

				print(f"Email sent successfully to {user.email}")
				print(f"Email ID: {result['id']}")
			except Exception as e:
				print(f"Error sending email to {user.email}: {e}")
	finally:
		try:
			next(db_generator)
		except StopIteration:
			pass


for message in consumer:
	send_email_notification(message.value)
	consumer.commit()
