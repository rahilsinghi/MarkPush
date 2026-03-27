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
import { loadConfig, addPairedDevice, saveConfig, type PairedDevice } from "../config/store.js";

export interface PairResult {
  deviceName: string;
  deviceId: string;
}

export interface PairingSession {
  qrCode: string;
  port: number;
  localIP: string;
  completion: Promise<PairResult>;
  cancel: () => void;
}

/**
 * Start the QR pairing flow and return immediately with the QR code.
 * The pairing server runs in the background until the iOS device connects
 * or the timeout expires. Callers should await `completion` or use
 * `list_devices` to verify success.
 */
export async function startPairing(timeoutSec: number = 120): Promise<PairingSession> {
  const cfg = loadConfig();

  // Generate pairing secret.
  const secret = randomBytes(32).toString("base64");
  const localIP = getLocalIP();

  let resolveCompletion!: (result: PairResult) => void;
  let rejectCompletion!: (err: Error) => void;
  const completion = new Promise<PairResult>((res, rej) => {
    resolveCompletion = res;
    rejectCompletion = rej;
  });

  // Prevent unhandled rejection if timeout fires after tool returns.
  completion.catch(() => {});

  return new Promise<PairingSession>((resolveSession, rejectSession) => {
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

            // Auto-populate user_id from Supabase if cloud is configured.
            if (cfg.cloud?.supabase_url && cfg.cloud?.supabase_key && !cfg.cloud.user_id) {
              fetchUserIdForDevice(cfg.cloud.supabase_url, cfg.cloud.supabase_key, data.device_id)
                .then((userId) => {
                  if (userId) {
                    const updated = loadConfig();
                    updated.cloud = { ...updated.cloud, user_id: userId };
                    saveConfig(updated);
                    process.stderr.write(`☁️  Auto-populated cloud user_id: ${userId}\n`);
                  }
                })
                .catch((err) => {
                  process.stderr.write(`⚠️  Could not auto-fetch user_id: ${(err as Error).message}\n`);
                });
            }

            resolveCompletion({ deviceName: data.device_name, deviceId: data.device_id });
          } catch (err) {
            res.writeHead(400);
            res.end("Invalid request");
            cleanup();
            rejectCompletion(new Error(`Pairing failed: ${(err as Error).message}`));
          }
        });
      } else {
        res.writeHead(404);
        res.end();
      }
    });

    const timeout = setTimeout(() => {
      cleanup();
      rejectCompletion(new Error(`Pairing timed out after ${timeoutSec}s`));
    }, timeoutSec * 1000);

    function cleanup() {
      clearTimeout(timeout);
      server.close();
    }

    function cancel() {
      cleanup();
      rejectCompletion(new Error("Pairing cancelled"));
    }

    // Listen on random port.
    server.listen(0, () => {
      const addr = server.address();
      if (!addr || typeof addr === "string") {
        cleanup();
        rejectSession(new Error("Failed to start pairing server"));
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

      const payloadJSON = JSON.stringify(payload);
      qrcode.generate(payloadJSON, { small: true }, (qr: string) => {
        // Still write to stderr for non-MCP consumers.
        process.stderr.write("\n📱 Scan this QR code with the MarkPush iOS app:\n\n");
        process.stderr.write(qr);
        process.stderr.write(`\nListening on ${localIP}:${port} — waiting for device...\n`);

        // Return session immediately — caller gets the QR without waiting.
        resolveSession({
          qrCode: qr,
          port,
          localIP,
          completion,
          cancel,
        });
      });
    });
  });
}

/** Fetch the Supabase user_id that owns a given device_id. */
async function fetchUserIdForDevice(
  supabaseUrl: string,
  supabaseKey: string,
  deviceId: string,
): Promise<string | null> {
  const resp = await fetch(
    `${supabaseUrl}/rest/v1/devices?device_id=eq.${encodeURIComponent(deviceId)}&select=user_id&limit=1`,
    {
      headers: {
        apikey: supabaseKey,
        Authorization: `Bearer ${supabaseKey}`,
      },
    },
  );
  if (!resp.ok) return null;
  const rows = (await resp.json()) as Array<{ user_id: string }>;
  return rows[0]?.user_id ?? null;
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
