from pprint import pprint
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.utils.snap_trade import snaptrade

response = snaptrade.account_information.get_account_activities(
    account_id="207f2627-489c-4dca-ba43-55530dd8c9f1",
    user_id="kondwani-123",
    user_secret="523aa0c9-e7d2-4aed-a02c-696e6a283a6a"
)
pprint(response.body)