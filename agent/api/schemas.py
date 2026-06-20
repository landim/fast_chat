from datetime import datetime
from pydantic import BaseModel


class ThreadOut(BaseModel):
    id: str
    title: str
    user_id: int
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ThreadCreate(BaseModel):
    user_id: int
    title: str = "New conversation"


class ThreadPatch(BaseModel):
    title: str
