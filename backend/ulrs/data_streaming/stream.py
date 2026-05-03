import json
import os

import certifi
import websocket
from dotenv import load_dotenv
from kafka import KafkaProducer
import json
import time

producer = KafkaProducer(
    bootstrap_servers='localhost:9092',
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

load_dotenv()


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
    handle incoming messages from the websocket
    '''
    print(message)
    producer.send('my-topic', value=message)

def on_error(ws, error):
    print(f"websocket error: {error}")


def on_close(ws, close_status_code, close_msg):
    '''
    handle websocket closure
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
