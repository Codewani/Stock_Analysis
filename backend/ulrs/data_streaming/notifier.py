from kafka import KafkaConsumer
from openai import OpenAI
import json
'''
alpaca news api response object:
{
    "T": "n",
    "id": 24918784,
    "headline": "Corsair Reports Purchase Of Majority Ownership In iDisplay, No Terms Disclosed",
    "summary": "Corsair Gaming, Inc. (NASDAQ:CRSR) (“Corsair”), a leading global provider and innovator of high-performance gear for gamers and content creators, today announced that it acquired a 51% stake in iDisplay",
    "author": "Benzinga Newsdesk",
    "created_at": "2022-01-05T22:00:37Z",
    "updated_at": "2022-01-05T22:00:38Z",
    "url": "https://www.benzinga.com/m-a/22/01/24918784/corsair-reports-purchase-of-majority-ownership-in-idisplay-no-terms-disclosed",
    "content": "\u003cp\u003eCorsair Gaming, Inc. (NASDAQ:\u003ca class=\"ticker\" href=\"https://www.benzinga.com/stock/CRSR#NASDAQ\"\u003eCRSR\u003c/a\u003e) (\u0026ldquo;Corsair\u0026rdquo;), a leading global ...",
    "symbols": ["CRSR"],
    "source": "benzinga"
}
'''

consumer = KafkaConsumer(
    'my-topic',
    bootstrap_servers='localhost:9092',
    auto_offset_reset='earliest',
    enable_auto_commit=False,
    group_id='my-consumer-group',
    value_deserializer=lambda v: json.loads(v.decode('utf-8'))
)

ai_client = OpenAI()


def send_push_notification(news_event):
    ai_response = ai_client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You role is to"
                    "analylize the news event in the content and determine "
                    "whether it is postive, negative, or neutral. "
                    "If it is positive send 'positive' with no extra characters (not even whitespace)"
                    " and likewise for when it is negative or neutral. "
                    "Once again, DO NOT SEND ANY OTHER CHARACTERS."
                    },
                    {"role": "user", "content": news_event.summary}
                ],
                max_tokens=100,
                temperature=0.7
    )
    sentiment = ai_response.choices[0].message.content.strip().lower()
    if sentiment != "neutral":
        '''
        implement push notifications
        '''
        print(f"Sending {sentiment} push notification for news event: {news_event.headline}")


for message in consumer:
    send_push_notification(message.value)
    consumer.commit()