import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, Request
from sqlalchemy.orm import Session

from database import Thread, User, engine
from api.schemas import ThreadCreate, ThreadOut, ThreadPatch

router = APIRouter(prefix="/threads", tags=["threads"])


@router.get("", response_model=list[ThreadOut])
def list_threads(user_id: Optional[int] = Query(None)):
    with Session(engine) as session:
        q = session.query(Thread).order_by(Thread.updated_at.desc())
        if user_id is not None:
            q = q.filter(Thread.user_id == user_id)
        return q.all()


@router.post("", response_model=ThreadOut, status_code=201)
def create_thread(body: ThreadCreate):
    with Session(engine) as session:
        if session.get(User, body.user_id) is None:
            raise HTTPException(status_code=404, detail="User not found")
        now = datetime.now(timezone.utc)
        thread = Thread(
            id=str(uuid.uuid4()),
            title=body.title,
            user_id=body.user_id,
            created_at=now,
            updated_at=now,
        )
        session.add(thread)
        session.commit()
        session.refresh(thread)
        return thread


@router.patch("/{thread_id}", response_model=ThreadOut)
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


@router.get("/{thread_id}/messages")
async def get_thread_messages(thread_id: str, request: Request):
    from ag_ui_langgraph.utils import langchain_messages_to_agui
    graph = getattr(request.app.state, "graph", None)
    if graph is None:
        return []
    state = await graph.aget_state({"configurable": {"thread_id": thread_id}})
    if not state or not state.values:
        return []
    messages = state.values.get("messages", [])
    agui_messages = langchain_messages_to_agui(messages)
    return [msg.model_dump() for msg in agui_messages]


@router.delete("/{thread_id}", status_code=204)
def delete_thread(thread_id: str):
    with Session(engine) as session:
        thread = session.get(Thread, thread_id)
        if thread is None:
            raise HTTPException(status_code=404, detail="Thread not found")
        session.delete(thread)
        session.commit()
