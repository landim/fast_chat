"use client";

import { useState } from "react";
import { CopilotKit, useCopilotAction } from "@copilotkit/react-core";
import { CopilotChat } from "@copilotkit/react-ui";
import { ThreadSidebar } from "./components/ThreadSidebar";
import { ThreadLoader } from "./components/ThreadLoader";
import { ToolCall } from "./components/ToolCall";
import { AskUserQuestion } from "./components/AskUserQuestion";
import styles from "./page.module.css";

function ChatWithToolRendering() {
  useCopilotAction(
    {
      name: "ask_user_question",
      description:
        "Ask the user a clarifying question to get more context before answering. " +
        "Use during reasoning when the request is ambiguous or missing detail.",
      parameters: [
        {
          name: "question",
          type: "string",
          description: "The question to ask the user",
          required: true,
        },
        {
          name: "options",
          type: "string[]",
          description: "Optional suggested answers shown as buttons",
          required: false,
        },
      ],
      renderAndWaitForResponse: ({ args, respond, status }) => (
        <AskUserQuestion
          question={(args.question as unknown) as string}
          options={(args.options as unknown) as string[] | undefined}
          status={status}
          respond={respond}
        />
      ),
    },
    []
  );
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
