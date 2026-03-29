from fastapi import FastAPI
from contextlib import asynccontextmanager
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv
import os
from models.users import Base
from ulrs.user import router
from database import engine

load_dotenv()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Only create tables if not in testing mode
    if not os.getenv("TESTING"):
        Base.metadata.create_all(bind=engine)
    yield

app = FastAPI(lifespan=lifespan)

app.include_router(router)

@app.get("/")
def read_root():
    return {"Hello": "World"}
