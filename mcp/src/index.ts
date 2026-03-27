#!/usr/bin/env node

/**
 * MarkPush MCP Server
 *
 * Push AI-generated markdown to your iPhone directly from Claude Code
 * or any MCP-compatible agentic terminal.
 *
 * Install: claude mcp add markpush -- npx -y @markpush/mcp-server
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

import { registerPushMarkdown } from "./tools/push-markdown.js";
import { registerPushTemplate } from "./tools/push-template.js";
import { registerPairDevice } from "./tools/pair-device.js";
import { registerListDevices } from "./tools/list-devices.js";
import { registerPushHistory } from "./tools/push-history.js";
import { registerUnpairDevice } from "./tools/unpair-device.js";
import { registerPrompts } from "./prompts/register.js";

const server = new McpServer({
  name: "markpush",
  version: "0.2.0",
});

// Register tools.
registerPushMarkdown(server);
registerPushTemplate(server);
registerPairDevice(server);
registerListDevices(server);
registerPushHistory(server);
registerUnpairDevice(server);

// Register prompt templates.
registerPrompts(server);

// Connect via stdio (standard for npx-distributed MCP servers).
const transport = new StdioServerTransport();
await server.connect(transport);
