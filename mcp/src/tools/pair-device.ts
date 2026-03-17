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
            `✅ Paired with ${result.deviceName}!`,
            `   Device ID: ${result.deviceId}`,
            `   Encryption key stored in ~/.config/markpush/config.toml`,
            "",
            "You can now use `push_markdown` to send documents to your iPhone.",
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
