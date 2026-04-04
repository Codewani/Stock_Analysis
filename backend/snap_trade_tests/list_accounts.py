from pprint import pprint
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.utils.snap_trade import snaptrade

response = snaptrade.account_information.list_user_accounts(
    user_id="kondwani_123",
    user_secret="8a8545e1-284b-4433-990f-0cdaccaeec17"
)
pprint(response.body)