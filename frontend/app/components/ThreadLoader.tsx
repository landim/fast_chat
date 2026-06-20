"use client";

import { useEffect, useRef } from "react";
import { useCopilotChatInternal } from "@copilotkit/react-core";

interface Props {
  threadId: string;
}

export function ThreadLoader({ threadId }: Props) {
  const { setMessages, isAvailable } = useCopilotChatInternal({});
  const apiUrl = process.env.NEXT_PUBLIC_API_URL!;
  const loadedRef = useRef<string | null>(null);

  useEffect(() => {
    if (!isAvailable || !threadId) return;
    if (loadedRef.current === threadId) return;
    loadedRef.current = threadId;

    setMessages([]);
    fetch(`${apiUrl}/threads/${threadId}/messages`)
      .then((r) => r.json())
      .then((msgs) => {
        if (Array.isArray(msgs) && msgs.length > 0) setMessages(msgs);
      })
      .catch(console.error);
  }, [threadId, isAvailable]);

  return null;
}
