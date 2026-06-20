"use client";

import { useState } from "react";
import { CopilotKit, useCopilotAction } from "@copilotkit/react-core";
import { CopilotChat } from "@copilotkit/react-ui";
import { ThreadSidebar } from "./components/ThreadSidebar";
import { ThreadLoader } from "./components/ThreadLoader";
import { ToolCall } from "./components/ToolCall";
import styles from "./page.module.css";

function ChatWithToolRendering() {
  useCopilotAction(
    {
      name: "*",
      render: ({ name, status }) => <ToolCall name={name} status={status} />,
    },
    []
  );
  return (
    <CopilotChat
      className={styles.chat}
      labels={{ title: "LangDB Agent", initial: "Ask me anything about users." }}
    />
  );
}

export default function Home() {
  const [activeThreadId, setActiveThreadId] = useState<string>("");

  return (
    <div className={styles.layout}>
      <ThreadSidebar
        activeThreadId={activeThreadId}
        onSelect={setActiveThreadId}
        userId={1}
      />
      <main className={styles.main}>
        {activeThreadId ? (
          <CopilotKit runtimeUrl="/api/copilotkit" threadId={activeThreadId}>
            <ThreadLoader threadId={activeThreadId} />
            <ChatWithToolRendering />
          </CopilotKit>
        ) : (
          <div className={styles.empty}>
            <p>Select a conversation or create a new one.</p>
          </div>
        )}
      </main>
    </div>
  );
}
