import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { runPairing } from "../pairing/server.js";

export const pairDeviceSchema = {
  timeout: z.number().optional().describe("Seconds to wait for pairing (default: 120)"),
};

export function registerPairDevice(server: McpServer) {
  server.tool("pair_device", "Pair with an iOS device by scanning a QR code", pairDeviceSchema, async (args) => {
    try {
      const result = await runPairing(args.timeout ?? 120);

      return {
        content: [{
          type: "text",
          text: [
            `✅ Paired with ${result.deviceName}`,
            `${"━".repeat(30)}`,
            `🔐 AES-256 encryption key established`,
            `📁 Saved to ~/.config/markpush/config.toml`,
            `📱 Device ID: ${result.deviceId}`,
            ``,
            `Ready! Use \`push_markdown\` to send documents.`,
          ].join("\n"),
        }],
      };
    } catch (err) {
      return {
        content: [{
          type: "text",
          text: `❌ Pairing failed: ${(err as Error).message}`,
        }],
        isError: true,
      };
    }
  });
}
