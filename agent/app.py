import json as _json
import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request as StarletteRequest
from starlette.responses import JSONResponse

from ag_ui_langgraph import add_langgraph_fastapi_endpoint
from copilotkit import LangGraphAGUIAgent
from langgraph.checkpoint.postgres.aio import AsyncPostgresSaver

from agent import builder
from auth import verify_id_token
from database import Thread, engine, get_or_create_user_by_cognito
from api.routes.threads import router as threads_router

load_dotenv()

POSTGRES_CONN = os.getenv(
    "DATABASE_URL",
    "postgresql://langdb:langdb@localhost:5442/langdb",
)

_origins_env = os.getenv("ALLOWED_ORIGINS", "http://localhost:3000")
ALLOWED_ORIGINS = [o.strip() for o in _origins_env.split(",") if o.strip()]


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with AsyncPostgresSaver.from_conn_string(POSTGRES_CONN) as checkpointer:
        await checkpointer.setup()
        compiled_graph = builder.compile(checkpointer=checkpointer)
        app.state.graph = compiled_graph

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


app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

_PROTECTED_PREFIXES = ("/agent", "/threads")

class AuthMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: StarletteRequest, call_next):
        if request.method == "OPTIONS":
            return await call_next(request)
        path = request.url.path
        if any(path == p or path.startswith(p + "/") for p in _PROTECTED_PREFIXES):
            auth = request.headers.get("authorization", "")
            if not auth.lower().startswith("bearer "):
                return JSONResponse(
                    {"detail": "Not authenticated"}, status_code=401,
                    headers={"WWW-Authenticate": "Bearer"},
                )
            token = auth.split(" ", 1)[1]
            try:
                payload = verify_id_token(token)
            except HTTPException as exc:
                return JSONResponse({"detail": exc.detail}, status_code=exc.status_code)
            request.state.cognito_payload = payload

            # Thread ownership check for /agent
            if path == "/agent" or path.startswith("/agent/"):
                try:
                    body_bytes = await request.body()
                    data = _json.loads(body_bytes)
                    thread_id = data.get("thread_id")
                    if thread_id:
                        sub = payload["sub"]
                        email = payload.get("email", "")
                        name = payload.get("name") or payload.get("cognito:username") or email
                        with Session(engine) as session:
                            user = get_or_create_user_by_cognito(session, sub, email, name)
                            thread = session.get(Thread, thread_id)
                            if thread is not None and thread.user_id != user.id:
                                return JSONResponse(
                                    {"detail": "Not your thread"}, status_code=403
                                )
                except Exception:
                    pass  # parsing failure → let request through

        return await call_next(request)

app.add_middleware(AuthMiddleware)

app.include_router(threads_router)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", "8000"))
    uvicorn.run("app:app", host="0.0.0.0", port=port, reload=True)
