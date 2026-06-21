"use client";

import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import {
  AuthenticationDetails,
  CognitoUser,
  CognitoUserPool,
  CognitoUserSession,
} from "amazon-cognito-identity-js";

interface AuthContextValue {
  user: CognitoUser | null;
  idToken: string | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  getIdToken: () => Promise<string | null>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<CognitoUser | null>(null);
  const [idToken, setIdToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const userPoolRef = useRef<CognitoUserPool | null>(null);

  // Fetch Cognito config at runtime (not baked at build time)
  useEffect(() => {
    let cancelled = false;

    async function init() {
      try {
        const res = await fetch("/api/config");
        if (!res.ok) throw new Error("Failed to fetch /api/config");
        const { userPoolId, clientId, region } = await res.json();

        if (!userPoolId || !clientId) {
          // Config not available (e.g. local dev without env vars) — skip auth
          return;
        }

        const poolData = { UserPoolId: userPoolId, ClientId: clientId };
        // region is stored for reference but the library uses it via the pool
        void region;

        const userPool = new CognitoUserPool(poolData);
        userPoolRef.current = userPool;

        // Attempt to restore an existing session
        const currentUser = userPool.getCurrentUser();
        if (currentUser) {
          await new Promise<void>((resolve) => {
            currentUser.getSession(
              (err: Error | null, session: CognitoUserSession | null) => {
                if (!cancelled && !err && session && session.isValid()) {
                  setUser(currentUser);
                  setIdToken(session.getIdToken().getJwtToken());
                }
                resolve();
              }
            );
          });
        }
      } catch (err) {
        console.error("[AuthProvider] init error:", err);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    init();
    return () => {
      cancelled = true;
    };
  }, []);

  const login = useCallback(
    (email: string, password: string): Promise<void> => {
      return new Promise((resolve, reject) => {
        const userPool = userPoolRef.current;
        if (!userPool) {
          reject(new Error("Auth not initialised — Cognito config not loaded"));
          return;
        }

        const cognitoUser = new CognitoUser({
          Username: email,
          Pool: userPool,
        });
        const authDetails = new AuthenticationDetails({
          Username: email,
          Password: password,
        });

        cognitoUser.authenticateUser(authDetails, {
          onSuccess: (session: CognitoUserSession) => {
            setUser(cognitoUser);
            setIdToken(session.getIdToken().getJwtToken());
            resolve();
          },
          onFailure: (err) => {
            reject(err);
          },
        });
      });
    },
    []
  );

  const logout = useCallback(() => {
    if (user) {
      user.signOut();
    }
    setUser(null);
    setIdToken(null);
  }, [user]);

  // Always re-calls getSession so the library's built-in refresh mechanism works
  const getIdToken = useCallback((): Promise<string | null> => {
    return new Promise((resolve) => {
      if (!user) {
        resolve(null);
        return;
      }
      user.getSession(
        (err: Error | null, session: CognitoUserSession | null) => {
          if (err || !session || !session.isValid()) {
            resolve(null);
            return;
          }
          const jwt = session.getIdToken().getJwtToken();
          // Keep state in sync after a silent refresh
          setIdToken(jwt);
          resolve(jwt);
        }
      );
    });
  }, [user]);

  const value: AuthContextValue = {
    user,
    idToken,
    loading,
    login,
    logout,
    getIdToken,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error("useAuth() must be used inside <AuthProvider>");
  }
  return ctx;
}
