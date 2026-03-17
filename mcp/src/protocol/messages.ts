/**
 * Shared protocol types matching the Go CLI and iOS app.
 * All JSON field names must match exactly.
 */

export const PROTOCOL_VERSION = "1";

export interface PushMessage {
  version: string;
  type: "push";
  id: string;
  timestamp: string; // ISO 8601
  title: string;
  tags?: string[];
  source?: string;
  word_count: number;
  content: string; // base64 encoded (optionally encrypted)
  encrypted: boolean;
  sender_id: string;
  sender_name: string;
}

export interface AckMessage {
  version: string;
  type: "ack";
  id: string;
  timestamp: string;
  ref_id: string;
  status: "received" | "error";
}

export interface PairInitPayload {
  v: string;
  s: string; // base64 secret
  h: string; // host IP
  p: number; // port
  id: string; // sender ID
  name: string; // sender name
}

/** Extract title from first H1 heading, or return "Untitled". */
export function extractTitle(markdown: string): string {
  const match = markdown.match(/^#\s+(.+)$/m);
  return match ? match[1].trim() : "Untitled";
}

/** Count whitespace-delimited words. */
export function countWords(markdown: string): number {
  const trimmed = markdown.trim();
  if (trimmed.length === 0) return 0;
  return trimmed.split(/\s+/).length;
}

/** Build a PushMessage from content and metadata. */
export function buildPushMessage(opts: {
  content: string;
  title?: string;
  tags?: string[];
  source?: string;
  senderID: string;
  senderName: string;
  encrypted?: boolean;
  encodedContent?: string;
}): PushMessage {
  const title = opts.title || extractTitle(opts.content);
  const encoded = opts.encodedContent ?? Buffer.from(opts.content, "utf-8").toString("base64");

  return {
    version: PROTOCOL_VERSION,
    type: "push",
    id: crypto.randomUUID(),
    timestamp: new Date().toISOString(),
    title,
    tags: opts.tags?.length ? opts.tags : undefined,
    source: opts.source || "claude",
    word_count: countWords(opts.content),
    content: encoded,
    encrypted: opts.encrypted ?? false,
    sender_id: opts.senderID,
    sender_name: opts.senderName,
  };
}
