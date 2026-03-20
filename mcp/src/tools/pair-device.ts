import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { startPairing } from "../pairing/server.js";

export const pairDeviceSchema = {
  timeout: z.number().optional().describe("Seconds to wait for pairing (default: 120)"),
};

// Track active session so we can cancel if re-invoked.
let activeCancel: (() => void) | null = null;

export function registerPairDevice(server: McpServer) {
  server.tool("pair_device", "Pair with an iOS device by scanning a QR code", pairDeviceSchema, async (args) => {
    try {
      // Cancel any existing pairing session.
      if (activeCancel) {
        activeCancel();
        activeCancel = null;
      }

      const session = await startPairing(args.timeout ?? 120);
      activeCancel = session.cancel;

      // Handle background completion.
      session.completion
        .then((result) => {
          activeCancel = null;
          process.stderr.write(`\n✅ Paired with ${result.deviceName} (${result.deviceId})\n`);
        })
        .catch((err) => {
          activeCancel = null;
          process.stderr.write(`\n❌ Pairing session ended: ${(err as Error).message}\n`);
        });

      // Return QR code immediately — pairing server continues in background.
      return {
        content: [{
          type: "text",
          text: [
            `📱 Scan this QR code with the MarkPush iOS app:\n`,
            session.qrCode,
            `\nListening on ${session.localIP}:${session.port} — waiting for device...`,
            ``,
            `After scanning, use \`list_devices\` to confirm pairing succeeded.`,
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
