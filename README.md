# langdb

A full-stack agentic chat app. A LangGraph ReAct agent backed by a Postgres database serves a `get_name` tool over the AG-UI protocol via FastAPI. The frontend is a Next.js + CopilotKit v2 app with a self-managed thread sidebar.

```
langdb/
├── agent/          # Python backend (FastAPI + LangGraph)
├── frontend/       # Next.js frontend (CopilotKit v2)
└── docker-compose.yml
```

## Requirements

- Python 3.11+, [uv](https://github.com/astral-sh/uv)
- Node.js 18+
- Docker (for Postgres)

## Setup

**1. Start Postgres**

```bash
docker compose up -d
```

**2. Backend**

```bash
cd agent
cp .env.example .env        # fill in OPENAI_API_KEY and LANGSMITH_API_KEY
uv pip install -e .
python seed_db.py           # creates tables and seeds Alice, Bob, Carol
uvicorn app:app --reload --port 8000
```

**3. Frontend**

```bash
cd frontend
cp .env.local.example .env.local   # or create it manually (see below)
npm install
npm run dev
```

`frontend/.env.local`:
```
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_AGENT_URL=http://localhost:8000/agent
```

Open [http://localhost:3000](http://localhost:3000), create a thread, and ask *"What is the name of user with id 2?"*

## Architecture

```
Next.js (CopilotKit v2, HttpAgent)
   │  AG-UI events (SSE)          REST: GET/POST/PATCH/DELETE /threads
   ▼                                      │
FastAPI  ──/agent──► LangGraph graph      │
   │                   └─ get_name ──► Postgres ◄── users table
   ├── AsyncPostgresSaver (thread history)
   └── Thread table (thread registry)
```

- **Thread history** — stored by LangGraph's `AsyncPostgresSaver` checkpointer, keyed by `thread_id`. CopilotKit restores the full conversation automatically when `threadId` changes.
- **Thread registry** (the sidebar list) — a plain SQLAlchemy `threads` table managed by our own REST routes.

## Agent

`agent/agent.py` defines the graph (manual `StateGraph`, not `create_react_agent`) so it's easy to extend. The same graph is used for:
- **CLI**: `python agent.py` (no checkpointer)
- **Server**: `uvicorn app:app` (compiled with `AsyncPostgresSaver` at startup)
- **LangSmith**: `langgraph.json` points to `agent.py:graph` for deployment

## Deploying to LangSmith

```bash
cd agent
langgraph dev      # local dev server
langgraph deploy   # deploy to LangSmith platform
```
