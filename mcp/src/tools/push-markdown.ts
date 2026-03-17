import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { loadConfig, getPairedDeviceKey, appendHistory } from "../config/store.js";
import { buildPushMessage } from "../protocol/messages.js";
import { encrypt } from "../crypto/aes.js";
import { autoSend } from "../transport/auto.js";

export const pushMarkdownSchema = {
  content: z.string().describe("Markdown content to push to the iOS device"),
  title: z.string().optional().describe("Override document title (auto-detected from first H1 otherwise)"),
  tags: z.array(z.string()).optional().describe("Tags for the document"),
  source: z.string().optional().describe("Source identifier (defaults to 'claude')"),
};

export function registerPushMarkdown(server: McpServer) {
  server.tool("push_markdown", "Push markdown content to your paired iPhone", pushMarkdownSchema, async (args) => {
    const cfg = loadConfig();

    if (!cfg.devices || cfg.devices.length === 0) {
      return {
        content: [{
          type: "text",
          text: "❌ No paired device found. Run the `pair_device` tool first to pair your iPhone.",
        }],
        isError: true,
      };
    }

    // Build the message.
    const msg = buildPushMessage({
      content: args.content,
      title: args.title,
      tags: args.tags,
      source: args.source ?? "claude",
      senderID: cfg.device_id,
      senderName: cfg.device_name,
    });

    // Encrypt if key available.
    const paired = getPairedDeviceKey(cfg);
    if (paired) {
      const encryptedContent = encrypt(paired.key, Buffer.from(args.content, "utf-8"));
      msg.content = encryptedContent;
      msg.encrypted = true;
    }

    // Send.
    try {
      const result = await autoSend(cfg, msg);

      // Record in history.
      appendHistory({
        id: msg.id,
        title: msg.title,
        word_count: msg.word_count,
        timestamp: msg.timestamp,
        transport: result.transport,
        device: cfg.devices![0].name,
      });

      return {
        content: [{
          type: "text",
          text: [
            `✅ Pushed "${msg.title}" to ${cfg.devices![0].name}`,
            `   Words: ${msg.word_count} | Transport: ${result.transport} | Encrypted: ${msg.encrypted}`,
            `   ID: ${msg.id}`,
          ].join("\n"),
        }],
      };
    } catch (err) {
      return {
        content: [{
          type: "text",
          text: `❌ Push failed: ${(err as Error).message}`,
        }],
        isError: true,
      };
    }
  });
}
