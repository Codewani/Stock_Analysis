from pprint import pprint
from snap_trade import snaptrade

response = snaptrade.authentication.register_snap_trade_user(
    user_id="kondwani-0312u"
)

print(response.body['userSecret'])