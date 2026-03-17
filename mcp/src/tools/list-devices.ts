import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { loadConfig } from "../config/store.js";

export function registerListDevices(server: McpServer) {
  server.tool("list_devices", "List all paired MarkPush iOS devices", {}, async () => {
    const cfg = loadConfig();
    const devices = cfg.devices ?? [];

    if (devices.length === 0) {
      return {
        content: [{
          type: "text",
          text: "No paired devices. Run `pair_device` to pair your iPhone.",
        }],
      };
    }

    const lines = devices.map((d, i) => `${i + 1}. ${d.name} (${d.id})`);

    return {
      content: [{
        type: "text",
        text: `Paired devices:\n${lines.join("\n")}`,
      }],
    };
  });
}
