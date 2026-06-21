from dotenv import load_dotenv
from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode
from langchain_openai import ChatOpenAI
from copilotkit import CopilotKitState
from database import get_name

load_dotenv()


class AgentState(CopilotKitState):
    pass


backend_tools = [get_name]
BACKEND_TOOL_NAMES = {t.name for t in backend_tools}
llm = ChatOpenAI(model="gpt-4o", reasoning_effort="auto")


def call_model(state: AgentState) -> dict:
    frontend_tools = (state.get("copilotkit") or {}).get("actions") or []
    model = llm.bind_tools([*backend_tools, *frontend_tools])
    response = model.invoke(state["messages"])
    return {"messages": [response]}


def should_continue(state: AgentState) -> str:
    last = state["messages"][-1]
    if not getattr(last, "tool_calls", None):
        return END
    if any(tc["name"] in BACKEND_TOOL_NAMES for tc in last.tool_calls):
        return "tools"
    return END


builder = StateGraph(AgentState)
builder.add_node("agent", call_model)
builder.add_node("tools", ToolNode(backend_tools))
builder.set_entry_point("agent")
builder.add_conditional_edges("agent", should_continue)
builder.add_edge("tools", "agent")

graph = builder.compile()


def run(prompt: str) -> str:
    result = graph.invoke({"messages": [("human", prompt)]})
    return result["messages"][-1].content


if __name__ == "__main__":
    print(run("What is the name of user with id 1?"))
