import json
import os
import certifi
import websocket
from dotenv import load_dotenv
from kafka import KafkaProducer
import json
from openai import OpenAI

NOTIFICATIONS_TOPIC = 'notifications'

producer = KafkaProducer(
    bootstrap_servers='localhost:9092',
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

load_dotenv()
ai_client = OpenAI()

def on_open(ws):
    print("opened")
    key = os.getenv("ALPACA_API_KEY")
    secret = os.getenv("ALPACA_CLIENT_SECRET")

    if not key or not secret:
        print("missing Alpaca API credentials")
        ws.close()
        return

    auth_data = {
        "action": "auth",
        "key": key,
        "secret": secret,
    }

    ws.send(json.dumps(auth_data))


def on_message(ws, message):
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
    ai_response = ai_client.chat.completions.create(
    model="gpt-4o-mini",
    response_format={
        "type": "json_schema",
        "json_schema": {
            "name": "sentiment_analysis",
            "schema": {
                "type": "object",
                "properties": {
                    "sentiment": {
                        "type": "string",
                        "enum": ["positive", "negative", "neutral"]
                    }
                },
                "required": ["sentiment"],
                "additionalProperties": False
            }
        }
    },
    messages=[
            {
            "role": "system",
            "content": (
                "You are a financial news sentiment classifier."
                )
            },
            {
            "role": "user",
            "content": message["summary"]
            }
        ],
        temperature=0
    )
    news_event = {
        "headline": message["headline"],
        "summary": message["summary"],
        "url": message["url"],
        "symbols": message["symbols"],
        "sentiment": json.loads(ai_response.choices[0].message.content)["sentiment"]
    }
    producer.send(NOTIFICATIONS_TOPIC, value=news_event)

def on_error(ws, error):
    print(f"websocket error: {error}")


def on_close(ws, close_status_code, close_msg):
    '''
    TODO: handle websocket closure
    '''


socket = "wss://stream.data.alpaca.markets/v1beta1/news"
ws = websocket.WebSocketApp(
    socket,
    on_open=on_open,
    on_message=on_message,
    on_error=on_error,
    on_close=on_close,
)
ws.run_forever(sslopt={"ca_certs": certifi.where()})
