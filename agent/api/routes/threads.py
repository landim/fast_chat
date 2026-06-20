import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException
from sqlalchemy.orm import Session

from database import Thread, engine
from api.schemas import ThreadOut, ThreadPatch

router = APIRouter(prefix="/threads", tags=["threads"])


@router.get("", response_model=list[ThreadOut])
def list_threads():
    with Session(engine) as session:
        return session.query(Thread).order_by(Thread.updated_at.desc()).all()


@router.post("", response_model=ThreadOut, status_code=201)
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


@router.delete("/{thread_id}", status_code=204)
def delete_thread(thread_id: str):
    with Session(engine) as session:
        thread = session.get(Thread, thread_id)
        if thread is None:
            raise HTTPException(status_code=404, detail="Thread not found")
        session.delete(thread)
        session.commit()
