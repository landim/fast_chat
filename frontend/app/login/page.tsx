"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "../auth/AuthContext";

export default function LoginPage() {
  const { login, completeNewPassword, idToken, loading } = useAuth();
  const router = useRouter();

  const [step, setStep] = useState<"login" | "new-password">("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  // Redirect immediately if already authenticated
  useEffect(() => {
    if (!loading && idToken) {
      router.push("/");
    }
  }, [loading, idToken, router]);

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      await login(email, password);
      router.push("/");
    } catch (err: unknown) {
      if (err instanceof Error && err.message === "NEW_PASSWORD_REQUIRED") {
        setStep("new-password");
      } else {
        const message =
          err instanceof Error ? err.message : "Login failed. Please try again.";
        setError(message);
      }
    } finally {
      setSubmitting(false);
    }
  }

  async function handleNewPassword(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (newPassword !== confirmPassword) {
      setError("Passwords do not match.");
      return;
    }
    setError(null);
    setSubmitting(true);
    try {
      await completeNewPassword(newPassword);
      router.push("/");
    } catch (err: unknown) {
      const message =
        err instanceof Error ? err.message : "Failed to set password. Please try again.";
      setError(message);
    } finally {
      setSubmitting(false);
    }
  }

  // While the auth context is initialising, show nothing to avoid flash
  if (loading) {
    return null;
  }

  if (step === "new-password") {
    return (
      <div style={styles.container}>
        <div style={styles.card}>
          <h1 style={styles.heading}>Set a new password</h1>
          <p style={styles.hint}>Your account requires a new password before you can continue.</p>

          <form onSubmit={handleNewPassword} style={styles.form}>
            <label style={styles.label} htmlFor="new-password">
              New password
            </label>
            <input
              id="new-password"
              type="password"
              autoComplete="new-password"
              required
              disabled={submitting}
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              style={styles.input}
            />

            <label style={styles.label} htmlFor="confirm-password">
              Confirm password
            </label>
            <input
              id="confirm-password"
              type="password"
              autoComplete="new-password"
              required
              disabled={submitting}
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              style={styles.input}
            />

            {error && <p style={styles.error}>{error}</p>}

            <button
              type="submit"
              disabled={submitting}
              style={{
                ...styles.button,
                ...(submitting ? styles.buttonDisabled : {}),
              }}
            >
              {submitting ? "Setting password…" : "Set password"}
            </button>
          </form>
        </div>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        <h1 style={styles.heading}>Sign in</h1>

        <form onSubmit={handleSubmit} style={styles.form}>
          <label style={styles.label} htmlFor="email">
            Email
          </label>
          <input
            id="email"
            type="email"
            autoComplete="email"
            required
            disabled={submitting}
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            style={styles.input}
          />

          <label style={styles.label} htmlFor="password">
            Password
          </label>
          <input
            id="password"
            type="password"
            autoComplete="current-password"
            required
            disabled={submitting}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            style={styles.input}
          />

          {error && <p style={styles.error}>{error}</p>}

          <button
            type="submit"
            disabled={submitting}
            style={{
              ...styles.button,
              ...(submitting ? styles.buttonDisabled : {}),
            }}
          >
            {submitting ? "Logging in…" : "Log in"}
          </button>
        </form>
      </div>
    </div>
  );
}

const styles = {
  container: {
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    minHeight: "100vh",
    backgroundColor: "#f5f5f5",
  } as React.CSSProperties,

  card: {
    backgroundColor: "#ffffff",
    borderRadius: "8px",
    boxShadow: "0 2px 12px rgba(0, 0, 0, 0.1)",
    padding: "40px 48px",
    width: "100%",
    maxWidth: "400px",
  } as React.CSSProperties,

  heading: {
    margin: "0 0 28px",
    fontSize: "24px",
    fontWeight: 600,
    color: "#111",
  } as React.CSSProperties,

  form: {
    display: "flex",
    flexDirection: "column",
    gap: "8px",
  } as React.CSSProperties,

  label: {
    fontSize: "14px",
    fontWeight: 500,
    color: "#444",
    marginTop: "8px",
  } as React.CSSProperties,

  input: {
    padding: "10px 12px",
    fontSize: "14px",
    border: "1px solid #d1d5db",
    borderRadius: "6px",
    outline: "none",
    width: "100%",
    boxSizing: "border-box",
  } as React.CSSProperties,

  hint: {
    margin: "-12px 0 16px",
    fontSize: "14px",
    color: "#6b7280",
  } as React.CSSProperties,

  error: {
    margin: "4px 0",
    fontSize: "13px",
    color: "#dc2626",
  } as React.CSSProperties,

  button: {
    marginTop: "16px",
    padding: "11px",
    fontSize: "15px",
    fontWeight: 600,
    color: "#ffffff",
    backgroundColor: "#2563eb",
    border: "none",
    borderRadius: "6px",
    cursor: "pointer",
  } as React.CSSProperties,

  buttonDisabled: {
    backgroundColor: "#93c5fd",
    cursor: "not-allowed",
  } as React.CSSProperties,
} as const;
