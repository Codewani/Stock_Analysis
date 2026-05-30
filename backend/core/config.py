from dataclasses import dataclass
import os

from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class Settings:
    postgres_url: str | None = os.getenv("POSTGRESURL")
    secret_key: str = os.getenv("SECRET_KEY", "development-secret-change-me")
    access_token_expire_minutes: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
    snaptrade_client_id: str | None = os.getenv("Client_Id")
    snaptrade_consumer_key: str | None = os.getenv("Secret")
    redis_url: str = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    alpaca_api_key: str | None = os.getenv("ALPACA_API_KEY")
    alpaca_client_secret: str | None = os.getenv("ALPACA_CLIENT_SECRET")
    openai_api_key: str | None = os.getenv("OPENAI_API_KEY")
    resend_api_key: str | None = os.getenv("RESEND_API_KEY")
    email_from: str = os.getenv("EMAIL_FROM", "Acme <alerts@notifications.codewani.com>")


settings = Settings()