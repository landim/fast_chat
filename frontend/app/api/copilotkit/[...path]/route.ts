import { NextRequest } from "next/server";
import { CopilotRuntime, createCopilotRuntimeHandler } from "@copilotkit/runtime/v2";
import { HttpAgent } from "@ag-ui/client";

// Build a per-request handler so each request carries its own Authorization header.
// HttpAgent only accepts static headers in its constructor, so we cannot share
// a module-level instance across requests that carry different Bearer tokens.
function buildHandler(req: NextRequest) {
  const authHeader = req.headers.get("authorization") ?? "";
  const runtime = new CopilotRuntime({
    agents: {
      // "default" is picked up automatically by <CopilotChat> with no agentId prop needed
      default: new HttpAgent({
        url: process.env.AGENT_URL!,
        ...(authHeader ? { headers: { Authorization: authHeader } } : {}),
      }),
    },
  });
  return createCopilotRuntimeHandler({
    runtime,
    basePath: "/api/copilotkit",
  });
}

export async function GET(req: NextRequest) {
  const handler = buildHandler(req);
  return handler(req);
}

export async function POST(req: NextRequest) {
  const handler = buildHandler(req);
  return handler(req);
}
