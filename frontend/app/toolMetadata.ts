export interface ToolMeta {
  alias: string;
  description: string;
}

export const TOOL_METADATA: Record<string, ToolMeta> = {
  get_name: {
    alias: "Look up user name",
    description: "Look up a user's name by their ID in the database.",
  },
};

export function getToolMeta(name: string): ToolMeta {
  return TOOL_METADATA[name] ?? { alias: name, description: "No description available." };
}
