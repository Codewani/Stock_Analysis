
from snaptrade_client import SnapTrade
import os
from dotenv import load_dotenv

load_dotenv()

CLIENT_ID = os.getenv("Client_Id")
CONSUMER_KEY = os.getenv("Secret")

snaptrade = SnapTrade(
    client_id=CLIENT_ID,
    consumer_key=CONSUMER_KEY
)