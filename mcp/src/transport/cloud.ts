/**
 * Cloud transport: sends PushMessage via Supabase REST API.
 * Matches the Go CLI protocol: includes user_id for RLS routing.
 */

import type { PushMessage } from "../protocol/messages.js";

export interface CloudConfig {
  supabaseUrl: string;
  supabaseKey: string;
  receiverId: string;
  userId?: string;
}

/** Send a PushMessage to the Supabase cloud relay. */
export async function sendViaCloud(config: CloudConfig, msg: PushMessage): Promise<void> {
  const body: Record<string, string> = {
    sender_id: msg.sender_id,
    receiver_id: config.receiverId,
    payload: JSON.stringify(msg),
  };

  // Include user_id for RLS-compliant routing (matches Go CLI behavior).
  if (config.userId) {
    body.user_id = config.userId;
  }

  const resp = await fetch(`${config.supabaseUrl}/rest/v1/pushes`, {
    method: "POST",
    headers: {
      apikey: config.supabaseKey,
      Authorization: `Bearer ${config.supabaseKey}`,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
    },
    body: JSON.stringify(body),
  });

  if (!resp.ok) {
    throw new Error(`Cloud relay error: HTTP ${resp.status}`);
  }
}
