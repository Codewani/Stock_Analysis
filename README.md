# Stock Analysis

Markets move fast. This project is built to keep up.

Stock Analysis combines a FastAPI backend, a PostgreSQL data layer, SnapTrade brokerage connections, and a Kafka-based news pipeline to help users track portfolios, manage watchlists, and route market-moving news into notifications. A SwiftUI frontend lives alongside the backend and is positioned to become the client experience for the platform.

## What This Project Does

- Registers users and issues auth tokens.
- Connects brokerage accounts through SnapTrade.
- Pulls account balances, holdings, activities, and orders.
- Stores account balance snapshots for historical tracking.
- Maintains per-user watchlists.
- Streams market news, classifies sentiment with OpenAI, and publishes notification events through Kafka.
- Sends email alerts for users whose holdings or watchlist symbols match incoming news.

## Architecture At A Glance

```text
SwiftUI App
    |
    v
FastAPI Backend
    |
    +--> PostgreSQL via SQLAlchemy
    |
    +--> SnapTrade for brokerage connectivity
    |
    +--> Redis caches for selected data paths
    |
    +--> Alpaca News WebSocket
            |
            v
        OpenAI sentiment classification
            |
            v
        Kafka topic: notifications
            |
            +--> email consumer
            +--> sms consumer (scaffolded)
            +--> push consumer (scaffolded)
```

## Repository Layout

```text
backend/
  main.py                      FastAPI entrypoint
  database.py                  SQLAlchemy engine and session factory
  models/                      Database models
  routers/
    auth/                      Registration, login, user profile APIs
    snap_trade/                SnapTrade connection and account data APIs
    watchlist/                 Watchlist APIs
    data_streaming/            Kafka consumers and market news stream
    utils/                     Auth, caching, DB, and helper utilities
  tests/                       Backend tests
  snap_trade_tests/            Manual/integration-style SnapTrade scripts

frontend/
  Stock_Analysis/              SwiftUI app
```

## Backend Features

### Authentication

- User registration with hashed passwords.
- JWT-based login flow.
- Current-user and user-by-id lookups.
- SnapTrade user registration during account creation.

### Portfolio Data

- List connected brokerage accounts.
- Fetch account activities.
- Fetch account balances.
- Fetch account orders.
- Refresh holdings and persist balance snapshots.
- Read historical balance snapshots.

### Watchlist

- Add symbols to a watchlist.
- Remove symbols from a watchlist.
- Read the authenticated user’s watchlist.

### News And Notifications

- Alpaca news events arrive via WebSocket.
- OpenAI classifies each story as `positive`, `negative`, or `neutral`.
- Kafka distributes normalized news events.
- The email consumer resolves matching users from holdings and watchlists, then sends notification emails with Resend.
- SMS and push consumers are present as scaffolds and are not fully implemented yet.

## API Surface

Current routers are mounted in the backend app entrypoint:

- `POST /register`
- `POST /login`
- `GET /users/me`
- `GET /users/{user_id}`
- `POST /snap_trade/connections/establish_connection`
- `GET /snap_trade/data/accounts`
- `GET /snap_trade/data/accounts/activities`
- `GET /snap_trade/data/accounts/balances`
- `POST /snap_trade/data/accounts/update`
- `GET /snap_trade/data/accounts/orders`
- `GET /snap_trade/data/accounts/balances/history`
- `GET /watchlist`
- `POST /add_to_watchlist`
- `POST /remove_from_watchlist`

## Tech Stack

- Python 3
- FastAPI
- SQLAlchemy
- PostgreSQL
- Redis
- Kafka
- SnapTrade
- OpenAI API
- Resend
- Twilio
- SwiftUI

## Environment Variables

Create a `.env` file in the backend directory with the values your setup needs.

```env
POSTGRESURL=postgresql://...
SECRET_KEY=replace-me
ACCESS_TOKEN_EXPIRE_MINUTES=30

Client_Id=your-snaptrade-client-id
Secret=your-snaptrade-consumer-key

REDIS_URL=redis://localhost:6379/0

ALPACA_API_KEY=your-alpaca-api-key
ALPACA_CLIENT_SECRET=your-alpaca-client-secret

OPENAI_API_KEY=your-openai-api-key

RESEND_API_KEY=your-resend-api-key
EMAIL_FROM=alerts@your-domain.com
```

## Quick Start

### 1. Install backend dependencies

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 2. Start infrastructure

You will need these services available for the full stack:

- PostgreSQL
- Redis
- Kafka

### 3. Run the API

From the repository root:

```bash
uvicorn backend.main:app --reload
```

### 4. Run the news stream producer

```bash
python backend/services/data_streaming/stream.py
```

### 5. Run notification consumers

Email:

```bash
python backend/services/data_streaming/emails.py
```

SMS:

```bash
python backend/services/data_streaming/sms.py
```

Push:

```bash
python backend/services/data_streaming/push_notifications.py
```

## Frontend

The SwiftUI app is currently a minimal shell inside `frontend/`. It establishes the client-side project structure, but most product behavior still lives in the backend today.

## Testing

Backend tests exist under `backend/tests/`.

```bash
cd backend
pytest
```

Note: the current local environment has a known `pytest` and `pytest-asyncio` mismatch, so test execution may require environment cleanup before running successfully.

## Current Status

What is already working:

- Core FastAPI app wiring
- User registration and login
- SnapTrade account and portfolio endpoints
- Watchlist management
- News ingestion and sentiment classification pipeline
- Email notification consumer

What is still in progress:

- SMS notifications
- Push notifications
- SwiftUI product UI
- Hardening around background workers, retries, and deployment

## Why This Project Is Interesting

This repository is more than a CRUD API for stock data. It is an event-driven portfolio assistant in early form: brokerage connectivity, historical balance snapshots, sentiment-aware news classification, and user-targeted notifications are already visible in the codebase. The next step is turning those pieces into a sharper user experience.

## License

No license file is currently present in the repository.