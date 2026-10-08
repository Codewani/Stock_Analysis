import asyncio
import json
import os
import random
from datetime import datetime, timezone

import websockets

HOST = os.getenv("FAKE_NEWS_HOST", "localhost")
PORT = 8765

FAKE_HEADLINES = [
    (
        "Amazon Beats Q3 Earnings Expectations",
        "Amazon.com Inc (NASDAQ:AMZN) reported quarterly earnings that topped "
        "analyst estimates, driven by strong demand in its cloud services "
        "division.",
        ["AMZN"],
    ),
    (
        "Meta Announces Surprise Leadership Shake-Up",
        "Meta Platforms Inc (NASDAQ:META) said a senior executive is stepping "
        "down effective immediately amid an ongoing internal reorganization.",
        ["META"],
    ),
    (
        "Tesla Unveils New Product Line at Annual Conference",
        "Tesla Inc (NASDAQ:TSLA) revealed a new suite of vehicle and energy "
        "products, with shares largely unchanged in early trading.",
        ["TSLA"],
    ),
    (
        "Meta Wins Regulatory Approval for New Feature Rollout",
        "Meta Platforms Inc (NASDAQ:META) received regulatory approval for its "
        "flagship product update, sending shares sharply higher.",
        ["META"],
    ),
    (
        "Amazon Faces Regulatory Probe Over Supply Chain",
        "Amazon.com Inc (NASDAQ:AMZN) confirmed it is under review by "
        "regulators over supplier practices, spooking investors.",
        ["AMZN"],
    ),
    (
        "Tesla Delivery Numbers Miss Analyst Estimates",
        "Tesla Inc (NASDAQ:TSLA) reported quarterly deliveries below Wall "
        "Street forecasts, citing production line adjustments.",
        ["TSLA"],
    ),
    (
        "Amazon and Meta Ramp Up AI Infrastructure Spending",
        "Amazon.com Inc (NASDAQ:AMZN) and Meta Platforms Inc (NASDAQ:META) "
        "both raised full-year capital expenditure guidance, citing "
        "accelerating investment in AI data centers.",
        ["AMZN", "META"],
    ),
    (
        "Apple Supplier Checks Point to Resilient iPhone Demand",
        "Apple Inc (NASDAQ:AAPL) shares rose after channel checks suggested "
        "steadier-than-expected demand heading into the holiday quarter.",
        ["AAPL"],
    ),
    (
        "NVIDIA Extends AI Lead as Enterprise Orders Accelerate",
        "NVIDIA Corp (NASDAQ:NVDA) said data-center customers continue to "
        "favor its latest chip generation, reinforcing pricing power.",
        ["NVDA"],
    ),
    (
        "Microsoft Cloud Revenue Tops Estimates on AI Demand",
        "Microsoft Corp (NASDAQ:MSFT) reported Azure growth ahead of "
        "expectations, driven by enterprise AI workload adoption.",
        ["MSFT"],
    ),
    (
        "Apple and NVIDIA Reportedly Deepen Chip Supply Partnership",
        "Apple Inc (NASDAQ:AAPL) and NVIDIA Corp (NASDAQ:NVDA) are said to be "
        "expanding a multi-year supply agreement for next-generation "
        "silicon.",
        ["AAPL", "NVDA"],
    ),
    (
        "Microsoft, Amazon, and Meta Face Antitrust Scrutiny Over Cloud Deals",
        "Regulators are reviewing cloud-computing agreements involving "
        "Microsoft Corp (NASDAQ:MSFT), Amazon.com Inc (NASDAQ:AMZN), and "
        "Meta Platforms Inc (NASDAQ:META) over competition concerns.",
        ["MSFT", "AMZN", "META"],
    ),
]


def build_news_event(headline: str, summary: str, symbols: list[str]) -> dict:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return {
        "T": "n",
        "id": random.randint(10_000_000, 99_999_999),
        "headline": headline,
        "summary": summary,
        "author": "Fake Newsdesk",
        "created_at": now,
        "updated_at": now,
        "url": "https://example.com/fake-news",
        "content": f"<p>{summary}</p>",
        "symbols": symbols,
        "source": "fake",
    }


async def handle_client(websocket):
    print("stream.py client connected")
    try:
        auth_payload = await websocket.recv()
        print(f"received auth payload: {auth_payload}")

        while True:
            headline, summary, symbols = random.choice(FAKE_HEADLINES)
            news_event = build_news_event(headline, summary, symbols)
            await websocket.send(json.dumps([news_event]))
            print(f"sent fake news: {news_event['headline']}")
            await asyncio.sleep(random.uniform(3, 8))
    except websockets.exceptions.ConnectionClosed:
        print("stream.py client disconnected")


async def main():
    async with websockets.serve(handle_client, HOST, PORT):
        print(f"fake news websocket server listening on ws://{HOST}:{PORT}")
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
