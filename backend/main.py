from contextlib import asynccontextmanager
import os

from dotenv import load_dotenv
from fastapi import FastAPI

from backend.api.v1.api import api_router
from backend.db.base import Base
from backend.db.session import engine

load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI):
	if not os.getenv("TESTING"):
		Base.metadata.create_all(bind=engine)
	yield


app = FastAPI(lifespan=lifespan)
app.include_router(api_router)


@app.get("/")
def read_root():
	return {"Hello": "World"}
