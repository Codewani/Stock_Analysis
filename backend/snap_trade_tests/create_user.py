from pprint import pprint
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.utils.snap_trade import snaptrade

response = snaptrade.authentication.register_snap_trade_user(
    user_id="kondwani-0312u"
)

print(response.body['userSecret'])