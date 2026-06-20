import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from ag_ui_langgraph import add_langgraph_fastapi_endpoint
from copilotkit import LangGraphAGUIAgent
from langgraph.checkpoint.postgres.aio import AsyncPostgresSaver

from agent import builder
from database import engine
from api.routes.threads import router as threads_router

load_dotenv()

POSTGRES_CONN = os.getenv(
    "DATABASE_URL",
    "postgresql://langdb:langdb@localhost:5442/langdb",
)


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
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(threads_router)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
