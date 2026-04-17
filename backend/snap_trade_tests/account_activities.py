from pprint import pprint
from pathlib import Path
import sys
import json
from backend.utils.snap_trade import snaptrade

response = snaptrade.account_information.get_account_activities(
    account_id="c44b086f-e931-4b04-9af1-eaba4a4bc134",
    user_id="kondwani_123",
    user_secret="8a8545e1-284b-4433-990f-0cdaccaeec17"
)
pprint(response.body)

# Save to JSON file
output_file = Path(__file__).parent / "activities.json"
with open(output_file, "w") as f:
    json.dump(response.body, f, indent=2)
print(f"\nActivities saved to: {output_file}")