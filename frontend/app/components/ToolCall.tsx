import { getToolMeta } from "../toolMetadata";
import styles from "./ToolCall.module.css";

interface ToolCallProps {
  name: string;
  status: "inProgress" | "executing" | "complete";
}

const STATUS_LABEL: Record<ToolCallProps["status"], string> = {
  inProgress: "Running…",
  executing: "Running…",
  complete: "Done",
};

export function ToolCall({ name, status }: ToolCallProps) {
  const meta = getToolMeta(name);
  const statusLabel = STATUS_LABEL[status] ?? status;

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <span className={styles.alias} title={name}>
          {meta.alias}
        </span>
        <span className={`${styles.status} ${styles[status]}`}>{statusLabel}</span>
      </div>
      <details className={styles.details}>
        <summary className={styles.summary}>Details</summary>
        <p className={styles.description}>{meta.description}</p>
      </details>
    </div>
  );
}
