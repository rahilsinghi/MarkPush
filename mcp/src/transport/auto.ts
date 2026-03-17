/**
 * Auto transport selection: tries WiFi first, falls back to cloud.
 */

import type { PushMessage } from "../protocol/messages.js";
import type { Config } from "../config/store.js";
import { discoverDevice, sendViaWiFi } from "./wifi.js";
import { sendViaCloud } from "./cloud.js";

export type TransportResult = { transport: "wifi" | "cloud" | "dry-run" };

/** Send a message using auto-selected transport. Returns which was used. */
export async function autoSend(cfg: Config, msg: PushMessage): Promise<TransportResult> {
  // Try WiFi first.
  try {
    const device = await discoverDevice(2_000);
    if (device) {
      await sendViaWiFi(device, msg);
      return { transport: "wifi" };
    }
  } catch {
    // WiFi failed, try cloud.
  }

  // Fall back to cloud.
  if (cfg.cloud?.supabase_url && cfg.cloud?.supabase_key) {
    const receiverId = cfg.devices?.[0]?.id;
    if (!receiverId) {
      throw new Error("No paired device found. Run the pair_device tool first.");
    }
    await sendViaCloud(
      {
        supabaseUrl: cfg.cloud.supabase_url,
        supabaseKey: cfg.cloud.supabase_key,
        receiverId,
      },
      msg,
    );
    return { transport: "cloud" };
  }

  throw new Error(
    "No device found on WiFi and cloud relay not configured. " +
      "Pair a device first with pair_device, or configure cloud relay.",
  );
}
