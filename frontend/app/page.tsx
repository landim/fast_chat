"use client";

import { useState } from "react";
import { HttpAgent } from "@ag-ui/client";
import { CopilotKit } from "@copilotkit/react-core";
import { CopilotChat } from "@copilotkit/react-ui";
import { ThreadSidebar } from "./components/ThreadSidebar";
import styles from "./page.module.css";

const agentUrl = process.env.NEXT_PUBLIC_AGENT_URL!;

export default function Home() {
  const [activeThreadId, setActiveThreadId] = useState<string>("");

  const agent = new HttpAgent({ url: agentUrl });

  return (
    <div className={styles.layout}>
      <ThreadSidebar
        activeThreadId={activeThreadId}
        onSelect={setActiveThreadId}
        userId={1}
      />
      <main className={styles.main}>
        {activeThreadId ? (
          <CopilotKit
            // eslint-disable-next-line @typescript-eslint/ban-ts-comment
            // @ts-ignore — direct HttpAgent connection (dev mode)
            agents__unsafe_dev_only={{ get_name_agent: agent }}
            agent="get_name_agent"
            threadId={activeThreadId}
          >
            <CopilotChat
              className={styles.chat}
              labels={{ title: "LangDB Agent", initial: "Ask me anything about users." }}
            />
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
