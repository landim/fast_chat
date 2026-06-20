import os
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ag_ui_langgraph import add_langgraph_fastapi_endpoint
from copilotkit import LangGraphAGUIAgent
from langgraph.checkpoint.postgres.aio import AsyncPostgresSaver

from agent import builder
from database import Base, Thread, engine

load_dotenv()

POSTGRES_CONN = os.getenv(
    "POSTGRES_CONN",
    "postgresql://langdb:langdb@localhost:5432/langdb",
)

# ── Pydantic schemas ─────────────────────────────────────────────────────────

class ThreadOut(BaseModel):
    id: str
    title: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ThreadPatch(BaseModel):
    title: str


# ── Lifespan ─────────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Ensure SQLAlchemy tables exist (users, threads)
    Base.metadata.create_all(engine)

    async with AsyncPostgresSaver.from_conn_string(POSTGRES_CONN) as checkpointer:
        await checkpointer.setup()
        compiled_graph = builder.compile(checkpointer=checkpointer)

        add_langgraph_fastapi_endpoint(
            app=app,
            agent=LangGraphAGUIAgent(
                name="get_name_agent",
                description="An agent that can look up user names from the database.",
                graph=compiled_graph,
            ),
            path="/agent",
        )

        yield


# ── App ───────────────────────────────────────────────────────────────────────

app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Thread routes ─────────────────────────────────────────────────────────────

@app.get("/threads", response_model=list[ThreadOut])
def list_threads():
    with Session(engine) as session:
        threads = session.query(Thread).order_by(Thread.updated_at.desc()).all()
        return threads


@app.post("/threads", response_model=ThreadOut, status_code=201)
def create_thread():
    now = datetime.now(timezone.utc)
    thread = Thread(
        id=str(uuid.uuid4()),
        title="New conversation",
        created_at=now,
        updated_at=now,
    )
    with Session(engine) as session:
        session.add(thread)
        session.commit()
        session.refresh(thread)
        return thread


@app.patch("/threads/{thread_id}", response_model=ThreadOut)
def rename_thread(thread_id: str, body: ThreadPatch):
    with Session(engine) as session:
        thread = session.get(Thread, thread_id)
        if thread is None:
            raise HTTPException(status_code=404, detail="Thread not found")
        thread.title = body.title
        thread.updated_at = datetime.now(timezone.utc)
        session.commit()
        session.refresh(thread)
        return thread


@app.delete("/threads/{thread_id}", status_code=204)
def delete_thread(thread_id: str):
    with Session(engine) as session:
        thread = session.get(Thread, thread_id)
        if thread is None:
            raise HTTPException(status_code=404, detail="Thread not found")
        session.delete(thread)
        session.commit()


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
