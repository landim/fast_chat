from dotenv import load_dotenv
from langgraph.graph import StateGraph, END
from langgraph.graph.message import MessagesState
from langgraph.prebuilt import ToolNode
from langchain_openai import ChatOpenAI
from sqlalchemy.orm import Session
from database import engine, get_name

load_dotenv()

tools = [get_name]
llm = ChatOpenAI(model="gpt-4o", temperature=0).bind_tools(tools)


def call_model(state: MessagesState) -> dict:
    response = llm.invoke(state["messages"])
    return {"messages": [response]}


def should_continue(state: MessagesState) -> str:
    last = state["messages"][-1]
    if last.tool_calls:
        return "tools"
    return END


builder = StateGraph(MessagesState)
builder.add_node("agent", call_model)
builder.add_node("tools", ToolNode(tools))
builder.set_entry_point("agent")
builder.add_conditional_edges("agent", should_continue)
builder.add_edge("tools", "agent")

graph = builder.compile()


def run(prompt: str) -> str:
    with Session(engine) as session:
        result = graph.invoke(
            {"messages": [("human", prompt)]},
            config={"configurable": {"db_session": session}},
        )
    return result["messages"][-1].content


if __name__ == "__main__":
    print(run("What is the name of user with id 1?"))
