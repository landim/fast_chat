from datetime import datetime
from pydantic import BaseModel


class ThreadOut(BaseModel):
    id: str
    title: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ThreadPatch(BaseModel):
    title: str
