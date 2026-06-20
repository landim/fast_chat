import { CopilotRuntime, createCopilotRuntimeHandler } from "@copilotkit/runtime/v2";
import { HttpAgent } from "@ag-ui/client";

const runtime = new CopilotRuntime({
  agents: {
    default: new HttpAgent({ url: process.env.AGENT_URL! }),
  },
});

// Handles POST /api/copilotkit (single-route mode fallback for auto-detect)
const handler = createCopilotRuntimeHandler({
  runtime,
  basePath: "/api/copilotkit",
  mode: "single-route",
});

export { handler as POST };
