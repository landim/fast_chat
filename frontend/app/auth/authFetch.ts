/**
 * Thin wrapper around fetch() that attaches Authorization: Bearer <idToken>.
 * getIdToken is the async accessor from AuthContext that handles refresh.
 */
export async function authFetch(
  getIdToken: () => Promise<string | null>,
  input: RequestInfo | URL,
  init?: RequestInit
): Promise<Response> {
  const token = await getIdToken();
  const headers = new Headers(init?.headers);
  if (token) headers.set("Authorization", `Bearer ${token}`);
  return fetch(input, { ...init, headers });
}
