import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { loadConfig, removePairedDevice } from "../config/store.js";

export const unpairDeviceSchema = {
  device_id: z.string().describe("ID of the device to unpair"),
};

export function registerUnpairDevice(server: McpServer) {
  server.tool("unpair_device", "Remove a paired device", unpairDeviceSchema, async (args) => {
    const cfg = loadConfig();
    const device = cfg.devices?.find((d) => d.id === args.device_id);

    if (!device) {
      return {
        content: [{ type: "text", text: `❌ Device ${args.device_id} not found.` }],
        isError: true,
      };
    }

    removePairedDevice(cfg, args.device_id);

    return {
      content: [{
        type: "text",
        text: `✅ Unpaired ${device.name} (${device.id}). Encryption key removed.`,
      }],
    };
  });
}
