import os
import sys
import time
from pathlib import Path
from pprint import pprint
from typing import Any

from dotenv import find_dotenv, load_dotenv
from fastapi.testclient import TestClient

ROOT = Path(__file__).resolve().parents[2]
BACKEND_ROOT = Path(__file__).resolve().parents[1]

for path in (str(BACKEND_ROOT), str(ROOT)):
    if path not in sys.path:
        sys.path.insert(0, path)

from backend.main import app

load_dotenv()

ENV_PATH = Path(find_dotenv() or Path(__file__).resolve().parents[2] / ".env")

USER_ID = "kondwani_123"
EMAIL = "kondwani_123@example.com"
PASSWORD = "TestPassword123!@#"


def register_user(client: TestClient, payload: dict[str, Any]) -> dict[str, Any]:
    response = client.post("/register", json=payload)
    if response.status_code not in (200, 201):
        body = response.json()
        detail = body.get("detail") if isinstance(body, dict) else body
        raise RuntimeError(
            f"Registration failed ({response.status_code}): {detail}"
        )
    return response.json()


def login_user(client: TestClient, username: str, password: str) -> dict[str, Any]:
    response = client.post(
        "/login",
        data={"username": username, "password": password},
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    if response.status_code != 200:
        body = response.json()
        raise RuntimeError(
            f"Login failed ({response.status_code}): {body.get('detail', body)}"
        )
    return response.json()


def create_robinhood_connection(client: TestClient, token: str) -> dict[str, Any]:
    response = client.post(
        "/snap_trade/connections",
        json={"broker": "ROBINHOOD"},
        headers={"Authorization": f"Bearer {token}"},
    )
    if response.status_code != 200:
        raise RuntimeError(
            f"Connection creation failed ({response.status_code}): {response.text}"
        )
    return response.json()


def create_account_balance_snapshot(client: TestClient, token: str) -> dict[str, Any]:
    response = client.post(
        "/snap_trade/data/accounts/update",
        headers={"Authorization": f"Bearer {token}"},
    )
    if response.status_code != 200:
        raise RuntimeError(
            f"Account balance snapshot request failed ({response.status_code}): {response.text}"
        )
    return response.json()


def main() -> None:
    client = TestClient(app)
    payload = {
        "user_id": USER_ID,
        "first_name": "Kondwani",
        "last_name": "Tester",
        "email": EMAIL,
        "phone_number": "555-0100",
        "password": PASSWORD,
    }

    print("Starting user simulation for", USER_ID)
    print(f"Using backend app with .env from {ENV_PATH}")

    try:
        register_response = register_user(client, payload)
        print("Registration succeeded:", register_response)
    except RuntimeError as exc:
        message = str(exc)
        print("Registration failed:", message)
        if "Email already registered" not in message and "user_id" not in message.lower():
            raise
        print("Proceeding with login for existing user.")

    login_response = login_user(client, username=USER_ID, password=PASSWORD)
    access_token = login_response["access_token"]
    print("Login succeeded. Received access token.")

    print("Creating Robinhood connection through the API endpoint...")
    portal_response = create_robinhood_connection(client, access_token)
    pprint(portal_response)
    if "redirectUrl" in portal_response:
        print("Open this URL in a browser to continue authentication:")
        print(portal_response["redirectUrl"])
    elif "url" in portal_response:
        print("Open this URL in a browser to continue authentication:")
        print(portal_response["url"])
    else:
        print("Response did not include an obvious redirect URL. Inspect the printed body above.")

    print("Waiting 2 minutes before creating an account balance snapshot...")
    time.sleep(70)

    print("Creating an account balance snapshot through the API endpoint...")
    snapshot_response = create_account_balance_snapshot(client, access_token)
    pprint(snapshot_response)


if __name__ == "__main__":
    main()
