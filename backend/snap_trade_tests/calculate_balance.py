import json
from pathlib import Path
from datetime import datetime
from collections import defaultdict
import yfinance as yf

# Load activities
activities_file = Path(__file__).parent / "activities.json"
with open(activities_file, "r") as f:
    data = json.load(f)

activities = data["data"]
# Sort by trade_date
activities.sort(key=lambda x: x["trade_date"])
# Initialize
cash_balance = 0.0
holdings = defaultdict(float)  # symbol: quantity
historical_balances = []

def get_price_on_date(symbol, date_str):
    try:
        from datetime import datetime, timedelta
        date = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
        today = datetime.now(date.tzinfo)
        if date > today:
            # Future date, use current price
            ticker = yf.Ticker(symbol)
            price = ticker.history(period="1d")["Close"].iloc[-1]
            return price
        start_date = date.date()
        end_date = (date + timedelta(days=1)).date()
        start_str = start_date.isoformat()
        end_str = end_date.isoformat()
        ticker = yf.Ticker(symbol)
        hist = ticker.history(start=start_str, end=end_str)
        if not hist.empty:
            return hist["Close"].iloc[0]
        # If no historical data, try current
        price = ticker.history(period="1d")["Close"].iloc[-1]
        return price
    except:
        return 0.0  # Fallback if API fails

for activity in activities:
    date = activity["trade_date"]
    act_type = activity["type"].upper()
    amount = activity.get("amount", 0.0)
    symbol = (activity.get("symbol") or {}).get("symbol", "")
    units = activity.get("units", 0.0)

    # Adjust cash
    if act_type in ["CONTRIBUTION", "WITHDRAWAL"]:
        cash_balance += amount
    else:
        price = activity.get("price", 0.0)
        cash_balance -= units * price
        holdings[symbol] += units
    if float(holdings[symbol]) <= 0:
            del holdings[symbol]


    # Calculate value of holdings on this date
    holdings_value = sum(holdings[sym] * get_price_on_date(sym, date) for sym in holdings)
    total_balance = cash_balance + holdings_value

    historical_balances.append({
        "date": date,
        "cash_balance": cash_balance,
        "holdings_value": holdings_value,
        "total_balance": total_balance,
        "holdings": dict(holdings)
    })

# Save to JSON
output_file = Path(__file__).parent / "historical_balances.json"
with open(output_file, "w") as f:
    json.dump(historical_balances, f, indent=2)

print(f"Historical balances calculated and saved to: {output_file}")
print(f"Final balance: ${historical_balances[-1]['total_balance']:.2f}" if historical_balances else "No activities found")