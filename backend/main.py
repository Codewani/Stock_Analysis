from fastapi import FastAPI
from contextlib import asynccontextmanager
from dotenv import load_dotenv
import os
from backend.models.auth.user import Base
from backend.ulrs.auth.user import router as auth_router
from backend.ulrs.snap_trade.data import router as snap_trade_data
from backend.ulrs.snap_trade.connections import router as snap_trade_connections
from backend.ulrs.watchlist.watchlist import router as watchlist_router
from backend.database import engine

load_dotenv()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Only create tables if not in testing mode
    if not os.getenv("TESTING"):
        Base.metadata.create_all(bind=engine)
    yield

app = FastAPI(lifespan=lifespan)

app.include_router(auth_router)
app.include_router(snap_trade_data)
app.include_router(snap_trade_connections)
app.include_router(watchlist_router)

@app.get("/")
def read_root():
    return {"Hello": "World"}
