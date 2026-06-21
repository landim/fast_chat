"use client";

import { useEffect, useRef } from "react";
import { useAgent } from "@copilotkit/react-core/v2";

interface Props {
  threadId: string;
}

export function ThreadLoader({ threadId }: Props) {
  const { agent } = useAgent();
  const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? "";
  const loadedRef = useRef<string | null>(null);

  useEffect(() => {
    if (!agent || !threadId) return;
    if (loadedRef.current === threadId) return;
    loadedRef.current = threadId;

    agent.setMessages([]);
    fetch(`${apiUrl}/threads/${threadId}/messages`)
      .then((r) => r.json())
      .then((msgs) => {
        if (Array.isArray(msgs) && msgs.length > 0) agent.setMessages(msgs);
      })
      .catch(console.error);
  }, [threadId, agent]);

  return null;
}
