/**
 * WiFi transport: sends PushMessage over raw TCP to a locally discovered iOS device.
 * Matches the Go CLI protocol: JSON bytes written directly to TCP socket, no framing.
 */

import { createConnection, type Socket } from "node:net";
import type { PushMessage, AckMessage } from "../protocol/messages.js";

const CONNECT_TIMEOUT = 10_000;
const WRITE_TIMEOUT = 10_000;
const ACK_READ_TIMEOUT = 10_000;

export interface DeviceInfo {
  name: string;
  host: string;
  port: number;
  id?: string;
}

/** Discover MarkPush devices on local network via mDNS. */
export async function discoverDevice(timeoutMs: number = 2_000): Promise<DeviceInfo | null> {
  // Dynamic import to handle missing native module gracefully.
  const mdns = await import("multicast-dns");
  const instance = mdns.default();

  return new Promise<DeviceInfo | null>((resolve) => {
    const timer = setTimeout(() => {
      instance.destroy();
      resolve(null);
    }, timeoutMs);

    instance.on("response", (response: any) => {
      for (const answer of response.answers) {
        if (answer.type === "PTR" && answer.data?.includes("_markpush._tcp")) {
          // Found a MarkPush service. Look for SRV and A records.
          const srv = response.additionals?.find((a: any) => a.type === "SRV");
          const a = response.additionals?.find((a: any) => a.type === "A");
          const txt = response.additionals?.find((a: any) => a.type === "TXT");

          if (srv && a) {
            clearTimeout(timer);
            instance.destroy();

            let deviceId: string | undefined;
            if (txt?.data) {
              const txtStr = Buffer.isBuffer(txt.data[0])
                ? txt.data.map((b: Buffer) => b.toString()).join("")
                : String(txt.data);
              const idMatch = txtStr.match(/id=([^\s]+)/);
              if (idMatch) deviceId = idMatch[1];
            }

            resolve({
              name: srv.data?.target || "MarkPush Device",
              host: a.data,
              port: srv.data?.port || 49152,
              id: deviceId,
            });
            return;
          }
        }
      }
    });

    // Query for MarkPush services.
    instance.query({
      questions: [{ name: "_markpush._tcp.local", type: "PTR" }],
    });
  });
}

/** Send a PushMessage over raw TCP to a device (matches Go CLI protocol). */
export async function sendViaWiFi(device: DeviceInfo, msg: PushMessage): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    const socket: Socket = createConnection(
      { host: device.host, port: device.port, timeout: CONNECT_TIMEOUT },
      () => {
        // Connected — write JSON payload directly (no framing, matching Go CLI).
        const payload = JSON.stringify(msg);
        socket.write(payload, "utf-8", (err) => {
          if (err) {
            socket.destroy();
            reject(new Error(`WiFi send failed: ${err.message}`));
            return;
          }
        });
      },
    );

    // Read ACK (best-effort, matching Go CLI behavior).
    const chunks: Buffer[] = [];
    const ackTimer = setTimeout(() => {
      socket.destroy();
      resolve(); // No ACK within timeout — message was still sent.
    }, ACK_READ_TIMEOUT);

    socket.on("data", (data) => {
      chunks.push(data);
      clearTimeout(ackTimer);

      try {
        const ack: AckMessage = JSON.parse(Buffer.concat(chunks).toString("utf-8"));
        if (ack.status === "error") {
          socket.destroy();
          reject(new Error(`Device reported error for message ${msg.id}`));
          return;
        }
      } catch {
        // Partial data or parse failure — non-fatal.
      }

      socket.destroy();
      resolve();
    });

    socket.on("timeout", () => {
      socket.destroy();
      reject(new Error(`WiFi connection timed out to ${device.host}:${device.port}`));
    });

    socket.on("error", (err) => {
      clearTimeout(ackTimer);
      reject(new Error(`WiFi connection error: ${err.message}`));
    });

    socket.on("close", () => {
      clearTimeout(ackTimer);
      resolve(); // If closed without ACK, message was still sent.
    });
  });
}
