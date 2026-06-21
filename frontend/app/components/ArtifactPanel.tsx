"use client";

import { useAgent } from "@copilotkit/react-core/v2";
import styles from "./ArtifactPanel.module.css";

export function ArtifactPanel() {
  const { agent } = useAgent();
  const artifact = (agent.state as Record<string, unknown> | null)?.artifact;

  if (!artifact) {
    return null;
  }

  return (
    <div className={styles.panel}>
      <div className={styles.content}>
        {typeof artifact === "string" ? (
          <pre className={styles.pre}>{artifact}</pre>
        ) : (
          <pre className={styles.pre}>{JSON.stringify(artifact, null, 2)}</pre>
        )}
      </div>
    </div>
  );
}
