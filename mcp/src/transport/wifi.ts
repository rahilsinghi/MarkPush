/**
 * WiFi transport: sends PushMessage over WebSocket to a locally discovered iOS device.
 */

import WebSocket from "ws";
import type { PushMessage, AckMessage } from "../protocol/messages.js";

const CONNECT_TIMEOUT = 5_000;
const WRITE_TIMEOUT = 10_000;

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

/** Send a PushMessage over WebSocket to a device. */
export async function sendViaWiFi(device: DeviceInfo, msg: PushMessage): Promise<void> {
  const url = `ws://${device.host}:${device.port}/ws`;

  return new Promise<void>((resolve, reject) => {
    const ws = new WebSocket(url, { handshakeTimeout: CONNECT_TIMEOUT });

    const timeout = setTimeout(() => {
      ws.close();
      reject(new Error(`WiFi send timed out connecting to ${url}`));
    }, WRITE_TIMEOUT);

    ws.on("open", () => {
      ws.send(JSON.stringify(msg), (err) => {
        if (err) {
          clearTimeout(timeout);
          ws.close();
          reject(new Error(`WiFi send failed: ${err.message}`));
          return;
        }
      });
    });

    ws.on("message", (data) => {
      clearTimeout(timeout);
      // Parse ack (best-effort).
      try {
        const ack: AckMessage = JSON.parse(data.toString());
        if (ack.status === "error") {
          ws.close();
          reject(new Error(`Device reported error for message ${msg.id}`));
          return;
        }
      } catch {
        // Ack parsing failure is non-fatal.
      }
      ws.close();
      resolve();
    });

    ws.on("error", (err) => {
      clearTimeout(timeout);
      reject(new Error(`WiFi connection error: ${err.message}`));
    });

    ws.on("close", () => {
      clearTimeout(timeout);
      resolve(); // If closed without ack, message was still sent.
    });
  });
}
