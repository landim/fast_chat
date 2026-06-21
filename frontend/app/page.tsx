"use client";

import { useState } from "react";
import { z } from "zod";
import {
  CopilotKit,
  CopilotChat,
  useRenderTool,
  useHumanInTheLoop,
} from "@copilotkit/react-core/v2";
import { useRouter } from "next/navigation";
import { useAuth } from "./auth/AuthContext";
import { ThreadSidebar } from "./components/ThreadSidebar";
import { ThreadLoader } from "./components/ThreadLoader";
import { ArtifactPanel } from "./components/ArtifactPanel";
import { ToolCall } from "./components/ToolCall";
import { AskUserQuestion } from "./components/AskUserQuestion";
import styles from "./page.module.css";

const askUserQuestionSchema = z.object({
  question: z
    .string()
    .describe("The question to ask the user"),
  options: z
    .array(z.string())
    .optional()
    .describe("Optional suggested answers shown as buttons"),
});

function AskUserQuestionRenderer({
  args,
  status,
  respond,
}: {
  args: { question?: string; options?: string[] };
  status: string;
  respond?: (result: unknown) => Promise<void>;
}) {
  return (
    <AskUserQuestion
      question={args.question ?? ""}
      options={args.options}
      status={status}
      respond={respond ? (answer: string) => { void respond(answer); } : undefined}
    />
  );
}

function ChatWithTools({ threadId }: { threadId: string }) {
  useRenderTool({
    name: "*",
    render: ({ name, status }) => <ToolCall name={name} status={status} />,
  });

  useHumanInTheLoop({
    name: "ask_user_question",
    description:
      "Ask the user a clarifying question to get more context before answering. " +
      "Use during reasoning when the request is ambiguous or missing detail.",
    parameters: askUserQuestionSchema,
    render: AskUserQuestionRenderer as unknown as React.ComponentType<any>,
  });

  if (!threadId) {
    return (
      <div className={styles.empty}>
        <p>Select a conversation or create a new one.</p>
      </div>
    );
  }

  return (
    <div className={styles.chatWrapper}>
      <ThreadLoader threadId={threadId} />
      <CopilotChat
        threadId={threadId}
        labels={{ modalHeaderTitle: "LangDB Agent", welcomeMessageText: "Ask me anything about users." }}
      />
    </div>
  );
}

export default function Home() {
  const [activeThreadId, setActiveThreadId] = useState<string>("");
  const { loading, idToken, getIdToken } = useAuth();
  const router = useRouter();

  if (loading) return null;

  if (!idToken) {
    router.replace("/login");
    return null;
  }

  return (
    <div className={styles.layout}>
      <ThreadSidebar
        activeThreadId={activeThreadId}
        onSelect={setActiveThreadId}
        getIdToken={getIdToken}
      />
      <main className={styles.main}>
        <CopilotKit
          runtimeUrl="/api/copilotkit"
          headers={{ Authorization: `Bearer ${idToken}` }}
        >
          <div className={styles.splitPane}>
            <div className={styles.chatArea}>
              <ChatWithTools threadId={activeThreadId} />
            </div>
            <ArtifactPanel />
          </div>
        </CopilotKit>
      </main>
    </div>
  );
}
