import { NextRequest } from "next/server";
import { CopilotRuntime, createCopilotRuntimeHandler } from "@copilotkit/runtime/v2";
import { HttpAgent } from "@ag-ui/client";

// The CopilotKit runtime automatically forwards the Authorization header from
// the incoming request via extractForwardableHeaders — do not pass it in the
// HttpAgent constructor or it will be duplicated and the token will be mangled.
const runtime = new CopilotRuntime({
  agents: {
    // "default" is picked up automatically by <CopilotChat> with no agentId prop needed
    default: new HttpAgent({ url: process.env.AGENT_URL! }),
  },
});

const handler = createCopilotRuntimeHandler({
  runtime,
  basePath: "/api/copilotkit",
});

export async function GET(req: NextRequest) {
  return handler(req);
}

export async function POST(req: NextRequest) {
  return handler(req);
}
