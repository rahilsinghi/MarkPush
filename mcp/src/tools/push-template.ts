import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { loadConfig, getPairedDeviceKey, appendHistory } from "../config/store.js";
import { buildPushMessage } from "../protocol/messages.js";
import { encrypt } from "../crypto/aes.js";
import { autoSend } from "../transport/auto.js";
import { renderTemplate, TEMPLATE_NAMES } from "../prompts/templates.js";

export const pushTemplateSchema = {
  template: z.enum(TEMPLATE_NAMES).describe("Template name to use"),
  data: z.record(z.unknown()).describe("Template-specific data object"),
  tags: z.array(z.string()).optional().describe("Additional tags"),
};

export function registerPushTemplate(server: McpServer) {
  server.tool(
    "push_template",
    "Push formatted markdown using a pre-built template (code-review, meeting-notes, daily-summary, bug-report)",
    pushTemplateSchema,
    async (args) => {
      const cfg = loadConfig();

      if (!cfg.devices || cfg.devices.length === 0) {
        return {
          content: [{ type: "text", text: "❌ No paired device. Run `pair_device` first." }],
          isError: true,
        };
      }

      // Render template.
      let markdown: string;
      try {
        markdown = renderTemplate(args.template, args.data);
      } catch (err) {
        return {
          content: [{ type: "text", text: `❌ Template error: ${(err as Error).message}` }],
          isError: true,
        };
      }

      const templateTags = [args.template, ...(args.tags ?? [])];

      const msg = buildPushMessage({
        content: markdown,
        tags: templateTags,
        source: "claude",
        senderID: cfg.device_id,
        senderName: cfg.device_name,
      });

      const paired = getPairedDeviceKey(cfg);
      if (paired) {
        msg.content = encrypt(paired.key, Buffer.from(markdown, "utf-8"));
        msg.encrypted = true;
      }

      try {
        const result = await autoSend(cfg, msg);

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
              `✅ Pushed to ${cfg.devices![0].name}`,
              ``,
              `📄 "${msg.title}" (template: ${args.template})`,
              `📝 ${msg.word_count} words · ${result.transport}${msg.encrypted ? " · encrypted" : ""}`,
              ...(templateTags.length ? [`🏷️  ${templateTags.join(", ")}`] : []),
            ].join("\n"),
          }],
        };
      } catch (err) {
        return {
          content: [{ type: "text", text: `❌ Push failed: ${(err as Error).message}` }],
          isError: true,
        };
      }
    },
  );
}
