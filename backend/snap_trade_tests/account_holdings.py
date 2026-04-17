from pprint import pprint
from snaptrade_client import SnapTrade

snaptrade = SnapTrade(
    client_id="KONDWANI-TEST-BYNKQ",
    consumer_key="A11hFq6FiM9H1rqoBQw3RJJsvT9ZtjgCIzLt99BoRK5OF0Pfjj"
)

response = snaptrade.account_information.get_user_holdings(
    account_id="b10663d1-ad02-452b-a9a2-5f930a2e4118",
    user_id="kondwani_123",
    user_secret="ea67c4be-8033-41e0-a3e6-2241e73bf762"
)
pprint(response.body)