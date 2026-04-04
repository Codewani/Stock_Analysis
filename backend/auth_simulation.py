import os
import uuid
from pathlib import Path
from typing import Any

from dotenv import find_dotenv, load_dotenv
from fastapi.testclient import TestClient

from main import app

load_dotenv()

ENV_PATH = Path(find_dotenv() or Path(__file__).resolve().parents[1] / ".env")


def generate_test_user() -> dict[str, str]:
    """Generate a test user object with unique identifiers."""
    unique_id = str(uuid.uuid4())[:8]
    return {
        "user_id": f"test_user_{unique_id}",
        "first_name": "Test",
        "last_name": "User",
        "email": f"test_{unique_id}@example.com",
        "phone_number": "555-0100",
        "password": "TestPassword123!@#",
    }


def update_env_token(token: str) -> None:
    os.environ["ACCESS_TOKEN"] = token
    print(f"Stored ACCESS_TOKEN in environment variable")


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


def read_current_user(client: TestClient, token: str) -> dict[str, Any]:
    response = client.get(
        "/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    if response.status_code != 200:
        body = response.json()
        raise RuntimeError(
            f"Current user check failed ({response.status_code}): {body.get('detail', body)}"
        )
    return response.json()


def main() -> None:
    user_payload = generate_test_user()

    client = TestClient(app)

    print("Starting authentication simulation against the real backend app.")
    print(f"Using live database URL from {ENV_PATH}")
    print(f"Test user: {user_payload['user_id']} ({user_payload['email']})")


    try:
        register_response = register_user(client, user_payload)
        print("Registration succeeded:", register_response)
    except RuntimeError as exc:
        message = str(exc)
        print("Registration could not complete:", message)
        if "Email already registered" not in message and "user_id" not in message.lower():
            raise
        print("Proceeding to login with existing account.")

    login_response = login_user(
        client,
        username=user_payload["email"],
        password=user_payload["password"],
    )
    print("Login succeeded. Received token.")

    access_token = login_response["access_token"]
    update_env_token(access_token)

    current_user = read_current_user(client, access_token)
    print("Current user validated with Authorization header:", current_user)


if __name__ == "__main__":
    main()
