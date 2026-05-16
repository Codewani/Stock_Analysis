from openai import OpenAI
import os
from dotenv import load_dotenv
import json
load_dotenv()

print(os.getenv("OPENAI_API_KEY"))
ai_client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
news_event = {
    "T": "n",
    "id": 24918784,
    "headline": "Corsair Reports Purchase Of Majority Ownership In iDisplay, No Terms Disclosed",
    "summary": "Corsair Gaming, Inc. (NASDAQ:CRSR) (“Corsair”), a leading global provider and innovator of high-performance gear for gamers and content creators, today announced that it acquired a 51% stake in iDisplay",
    "author": "Benzinga Newsdesk",
    "created_at": "2022-01-05T22:00:37Z",
    "updated_at": "2022-01-05T22:00:38Z",
    "url": "https://www.benzinga.com/m-a/22/01/24918784/corsair-reports-purchase-of-majority-ownership-in-idisplay-no-terms-disclosed",
    "content": "\u003cp\u003eCorsair Gaming, Inc. (NASDAQ:\u003ca class=\"ticker\" href=\"https://www.benzinga.com/stock/CRSR#NASDAQ\"\u003eCRSR\u003c/a\u003e) (\u0026ldquo;Corsair\u0026rdquo;), a leading global ...",
    "symbols": ["CRSR"],
    "source": "benzinga"
}

ai_response = ai_client.chat.completions.create(
    model="gpt-4o-mini",
    response_format={
        "type": "json_schema",
        "json_schema": {
            "name": "sentiment_analysis",
            "schema": {
                "type": "object",
                "properties": {
                    "sentiment": {
                        "type": "string",
                        "enum": ["positive", "negative", "neutral"]
                    }
                },
                "required": ["sentiment"],
                "additionalProperties": False
            }
        }
    },
    messages=[
        {
            "role": "system",
            "content": (
                "You are a financial news sentiment classifier."
            )
        },
        {
            "role": "user",
            "content": news_event["summary"]
        }
    ],
    temperature=0
)

sentiment = json.loads(ai_response.choices[0].message.content)["sentiment"]
if sentiment != "neutral":
    print(f"Sending {sentiment} push notification for news event: {news_event["headline"]}")
