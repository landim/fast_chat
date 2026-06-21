"use client";

import { useState } from "react";
import styles from "./AskUserQuestion.module.css";

interface AskUserQuestionProps {
  question: string;
  options?: string[];
  status: "inProgress" | "executing" | "complete";
  respond?: (answer: string) => void;
}

export function AskUserQuestion({
  question,
  options,
  status,
  respond,
}: AskUserQuestionProps) {
  const [answered, setAnswered] = useState(false);
  const [answeredWith, setAnsweredWith] = useState<string | null>(null);
  const [inputValue, setInputValue] = useState("");

  function submit(answer: string) {
    if (answered || !respond) return;
    setAnswered(true);
    setAnsweredWith(answer);
    respond(answer);
  }

  function handleSend() {
    const trimmed = inputValue.trim();
    if (!trimmed) return;
    submit(trimmed);
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Enter") {
      handleSend();
    }
  }

  const hasOptions = Array.isArray(options) && options.length > 0;
  const isInteractive = status === "executing" && !answered;

  return (
    <div className={styles.container}>
      <p className={styles.question}>{question}</p>

      {status === "executing" && (
        <>
          {hasOptions && (
            <div className={styles.options}>
              {options!.map((opt) => (
                <button
                  key={opt}
                  className={styles.optionBtn}
                  onClick={() => submit(opt)}
                  disabled={!isInteractive}
                >
                  {opt}
                </button>
              ))}
            </div>
          )}

          <div className={styles.inputRow}>
            <input
              className={styles.textInput}
              type="text"
              placeholder="Type your answer…"
              value={inputValue}
              onChange={(e) => setInputValue(e.target.value)}
              onKeyDown={handleKeyDown}
              disabled={!isInteractive}
            />
            <button
              className={styles.sendBtn}
              onClick={handleSend}
              disabled={!isInteractive}
            >
              Send
            </button>
          </div>
        </>
      )}

      {status === "complete" && (
        <div className={styles.answeredRow}>
          {answeredWith != null ? (
            <span>
              <strong>Your answer:</strong> {answeredWith}
            </span>
          ) : (
            <span className={styles.answeredPill}>Answered</span>
          )}
        </div>
      )}
    </div>
  );
}
