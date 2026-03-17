/**
 * Ephemeral HTTP pairing server + QR code generation.
 * Reuses the same flow as the Go CLI — iOS app needs no changes.
 */

import { createServer } from "node:http";
import { randomBytes } from "node:crypto";
import { networkInterfaces } from "node:os";
import qrcode from "qrcode-terminal";
import { deriveKey } from "../crypto/aes.js";
import type { PairInitPayload } from "../protocol/messages.js";
import { loadConfig, addPairedDevice, type PairedDevice } from "../config/store.js";

export interface PairResult {
  deviceName: string;
  deviceId: string;
}

/**
 * Run the QR pairing flow:
 * 1. Generate 32-byte secret
 * 2. Start HTTP server
 * 3. Generate QR code with pairing payload
 * 4. Wait for iOS POST /pair
 * 5. Derive + store shared key
 */
export async function runPairing(timeoutSec: number = 120): Promise<PairResult> {
  const cfg = loadConfig();

  // Generate pairing secret.
  const secret = randomBytes(32).toString("base64");
  const localIP = getLocalIP();

  return new Promise<PairResult>((resolve, reject) => {
    const server = createServer((req, res) => {
      if (req.method === "POST" && req.url === "/pair") {
        let body = "";
        req.on("data", (chunk) => (body += chunk));
        req.on("end", () => {
          try {
            const data = JSON.parse(body) as { device_id: string; device_name: string };

            // Derive shared key.
            const key = deriveKey(secret, data.device_id);

            // Save paired device.
            const device: PairedDevice = {
              id: data.device_id,
              name: data.device_name,
              key: key.toString("base64"),
            };
            addPairedDevice(cfg, device);

            // Respond to iOS.
            res.writeHead(200, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ confirmed: true }));

            cleanup();
            resolve({ deviceName: data.device_name, deviceId: data.device_id });
          } catch (err) {
            res.writeHead(400);
            res.end("Invalid request");
            cleanup();
            reject(new Error(`Pairing failed: ${(err as Error).message}`));
          }
        });
      } else {
        res.writeHead(404);
        res.end();
      }
    });

    const timeout = setTimeout(() => {
      cleanup();
      reject(new Error(`Pairing timed out after ${timeoutSec}s`));
    }, timeoutSec * 1000);

    function cleanup() {
      clearTimeout(timeout);
      server.close();
    }

    // Listen on random port.
    server.listen(0, () => {
      const addr = server.address();
      if (!addr || typeof addr === "string") {
        cleanup();
        reject(new Error("Failed to start pairing server"));
        return;
      }

      const port = addr.port;

      // Build QR payload.
      const payload: PairInitPayload = {
        v: "1",
        s: secret,
        h: localIP,
        p: port,
        id: cfg.device_id,
        name: cfg.device_name,
      };

      // Print QR code to stderr (stdout is reserved for MCP protocol).
      const payloadJSON = JSON.stringify(payload);
      qrcode.generate(payloadJSON, { small: true }, (qr: string) => {
        process.stderr.write("\n📱 Scan this QR code with the MarkPush iOS app:\n\n");
        process.stderr.write(qr);
        process.stderr.write(`\nListening on ${localIP}:${port} — waiting for device...\n`);
      });
    });
  });
}

/** Get the preferred local IP address. */
function getLocalIP(): string {
  const interfaces = networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name] ?? []) {
      if (iface.family === "IPv4" && !iface.internal) {
        return iface.address;
      }
    }
  }
  return "127.0.0.1";
}
