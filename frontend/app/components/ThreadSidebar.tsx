"use client";

import { useEffect, useState } from "react";
import { Thread } from "../types";
import { authFetch } from "../auth/authFetch";
import styles from "./ThreadSidebar.module.css";

interface Props {
  activeThreadId: string | null;
  onSelect: (id: string) => void;
  getIdToken: () => Promise<string | null>;
}

export function ThreadSidebar({ activeThreadId, onSelect, getIdToken }: Props) {
  const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? "";
  const [threads, setThreads] = useState<Thread[]>([]);

  const fetchThreads = () =>
    authFetch(getIdToken, `${apiUrl}/threads`)
      .then((r) => r.json())
      .then(setThreads)
      .catch(console.error);

  useEffect(() => {
    fetchThreads();
  }, [getIdToken]);

  const createThread = async () => {
    const res = await authFetch(getIdToken, `${apiUrl}/threads`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: "New conversation" }),
    });
    if (!res.ok) return;
    const thread: Thread = await res.json();
    setThreads((prev) => [thread, ...prev]);
    onSelect(thread.id);
  };

  const deleteThread = async (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    await authFetch(getIdToken, `${apiUrl}/threads/${id}`, { method: "DELETE" });
    setThreads((prev) => prev.filter((t) => t.id !== id));
    if (activeThreadId === id) onSelect("");
  };

  return (
    <aside className={styles.sidebar}>
      <button className={styles.newBtn} onClick={createThread}>
        + New chat
      </button>
      <ul className={styles.list}>
        {threads.map((t) => (
          <li
            key={t.id}
            className={`${styles.item} ${t.id === activeThreadId ? styles.active : ""}`}
            onClick={() => onSelect(t.id)}
          >
            <span className={styles.title}>{t.title}</span>
            <button
              className={styles.del}
              onClick={(e) => deleteThread(t.id, e)}
              title="Delete"
            >
              ×
            </button>
          </li>
        ))}
      </ul>
    </aside>
  );
}
