from pprint import pprint
from snap_trade import snaptrade

response = snaptrade.authentication.login_snap_trade_user(
    user_id="kondwani-123",
    user_secret="523aa0c9-e7d2-4aed-a02c-696e6a283a6a",
    broker="ROBINHOOD",
    immediate_redirect=True,
    custom_redirect="https://snaptrade.com",
    reconnect="",
    show_close_button=True,
    dark_mode=True,
    connection_portal_version="v4"
)
pprint(response.body)