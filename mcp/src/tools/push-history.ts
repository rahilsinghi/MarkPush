import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { loadHistory } from "../config/store.js";

export const pushHistorySchema = {
  limit: z.number().optional().describe("Number of entries to show (default: 20)"),
};

export function registerPushHistory(server: McpServer) {
  server.tool("push_history", "Show recent push history", pushHistorySchema, async (args) => {
    const limit = args.limit ?? 20;
    const entries = loadHistory().slice(0, limit);

    if (entries.length === 0) {
      return {
        content: [{ type: "text", text: "No push history yet." }],
      };
    }

    const lines = entries.map((e) => {
      const date = new Date(e.timestamp).toLocaleString();
      return `• "${e.title}" — ${e.word_count} words — ${e.transport} — ${date}`;
    });

    return {
      content: [{
        type: "text",
        text: `Recent pushes (${entries.length}):\n${lines.join("\n")}`,
      }],
    };
  });
}
