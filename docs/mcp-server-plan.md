# MarkPush MCP Server — Implementation Plan

> Turn MarkPush into an AI-native tool. Push LLM-generated markdown to your iPhone directly from Claude Code or any MCP-compatible agentic terminal.

## Overview

```
Claude Code / Agentic Terminal
         │
         ▼
   ┌─────────────────────┐
   │  @markpush/mcp      │   ← npm package, runs via stdio
   │  (TypeScript)       │
   │                     │
   │  Tools:             │
   │  • push_markdown    │
   │  • push_template    │
   │  • pair_device      │
   │  • list_devices     │
   │  • push_history     │
   │  • unpair_device    │
   │                     │
   │  Prompts:           │
   │  • code-review      │
   │  • meeting-notes    │
   │  • daily-summary    │
   │  • bug-report       │
   └────────┬────────────┘
            │
     AES-256-GCM encrypted
            │
    ┌───────┴───────┐
    │               │
  WiFi            Cloud
  (WebSocket      (Supabase
  + mDNS)         Realtime)
    │               │
    └───────┬───────┘
            ▼
      iPhone App
    MarkPush Reader
```

## How Users Install It

```bash
# One command to add to Claude Code
claude mcp add markpush -- npx -y @markpush/mcp-server

# First time any tool is called, MCP server prompts pairing
# User calls pair_device tool → QR code in terminal → scan with iOS app → done
```

## Architecture

### Package Structure

```
mcp/                              ← New directory in monorepo
├── package.json                  ← @markpush/mcp-server
├── tsconfig.json
├── src/
│   ├── index.ts                  ← Entry point: McpServer + StdioServerTransport
│   ├── tools/
│   │   ├── push-markdown.ts      ← push_markdown tool
│   │   ├── push-template.ts      ← push_template tool
│   │   ├── pair-device.ts        ← pair_device tool (QR pairing)
│   │   ├── list-devices.ts       ← list_devices tool
│   │   ├── push-history.ts       ← push_history tool
│   │   └── unpair-device.ts      ← unpair_device tool
│   ├── prompts/
│   │   ├── code-review.ts        ← Pre-built prompt template
│   │   ├── meeting-notes.ts
│   │   ├── daily-summary.ts
│   │   └── bug-report.ts
│   ├── transport/
│   │   ├── wifi.ts               ← WebSocket + mDNS sender
│   │   ├── cloud.ts              ← Supabase REST sender
│   │   └── auto.ts               ← WiFi-first, cloud fallback
│   ├── crypto/
│   │   ├── aes.ts                ← AES-256-GCM (matching CLI format)
│   │   └── pbkdf2.ts             ← Key derivation
│   ├── config/
│   │   ├── store.ts              ← ~/.config/markpush/ read/write
│   │   └── devices.ts            ← Paired device management
│   ├── protocol/
│   │   └── messages.ts           ← PushMessage, AckMessage types
│   └── pairing/
│       ├── qr.ts                 ← QR code generation
│       └── server.ts             ← Ephemeral HTTP pairing server
├── tests/
│   ├── tools/
│   ├── transport/
│   └── crypto/
└── dist/                         ← Compiled output
```

### Tool Definitions

#### `push_markdown`
Push raw markdown content to a paired device.
```
Input:
  content: string    (required) — markdown content
  title: string      (optional) — override auto-detected title
  tags: string[]     (optional) — document tags
  source: string     (optional) — source identifier, defaults to "claude"

Output:
  message_id: string
  title: string
  word_count: number
  encrypted: boolean
  transport: "wifi" | "cloud"
```

#### `push_template`
Push markdown generated from a pre-built template.
```
Input:
  template: string   (required) — template name: "code-review", "meeting-notes", etc.
  data: object       (required) — template-specific data (varies per template)
  tags: string[]     (optional) — additional tags

Output:
  Same as push_markdown
```

#### `pair_device`
Start QR code pairing flow.
```
Input:
  timeout: number    (optional) — seconds to wait, default 120

Output:
  device_name: string
  device_id: string
  status: "paired"
```

#### `list_devices`
List all paired devices.
```
Input: (none)

Output:
  devices: Array<{ id, name, paired_at }>
```

#### `push_history`
Show recent pushes.
```
Input:
  limit: number      (optional) — default 20

Output:
  pushes: Array<{ id, title, word_count, timestamp, transport, device }>
```

#### `unpair_device`
Remove a paired device.
```
Input:
  device_id: string  (required)

Output:
  status: "unpaired"
```

### Prompt Templates

#### `code-review`
```
Input: { code: string, language: string, context?: string }
Generates: Formatted code review markdown with sections:
  - Summary, Issues Found (severity-tagged), Suggestions, Overall Assessment
```

#### `meeting-notes`
```
Input: { topic: string, attendees: string[], key_points: string[] }
Generates: Structured meeting notes with action items and follow-ups
```

#### `daily-summary`
```
Input: { tasks_completed: string[], blockers?: string[], tomorrow?: string[] }
Generates: Daily standup summary with progress and plan
```

#### `bug-report`
```
Input: { title: string, steps: string[], expected: string, actual: string }
Generates: Structured bug report markdown
```

## Auth Flow (QR Pairing)

```
┌─────────────────┐          ┌─────────────────┐
│  Claude Code     │          │  iPhone App      │
│  (MCP Client)    │          │  (MarkPush)      │
└───────┬─────────┘          └───────┬─────────┘
        │                             │
  1. User calls                       │
     pair_device tool                 │
        │                             │
  2. MCP Server generates             │
     32-byte secret,                  │
     starts HTTP server,              │
     renders QR in terminal           │
        │                             │
        │              3. User scans QR code
        │                    with iOS app
        │                             │
        │◄──── 4. POST /pair ────────│
        │      { device_id,           │
        │        device_name }        │
        │                             │
        │───── 5. 200 OK ───────────►│
        │      { confirmed: true }    │
        │                             │
  6. Both derive shared key:          │
     PBKDF2(secret, device_id,        │
            100000, SHA-256)          │
        │                             │
  7. MCP stores key in                │
     ~/.config/markpush/              │
        │                             │
  8. Returns success to               │
     Claude Code                      │
        │                             │
```

## Data Flow: push_markdown

```
┌─────────────────┐
│  Claude Code     │
│  calls tool:     │
│  push_markdown   │
│  { content,      │
│    title, tags } │
└───────┬─────────┘
        │
        ▼
┌─────────────────┐
│  MCP Server      │
│                  │
│  1. Load config  │
│  2. Build msg    │
│  3. Base64       │
│     encode       │
│  4. AES-256-GCM  │
│     encrypt      │
│  5. Select       │
│     transport    │
└───────┬─────────┘
        │
   ┌────┴────┐
   │         │
   ▼         ▼
┌──────┐ ┌──────┐
│ WiFi │ │Cloud │
│ WS   │ │Supa- │
│+mDNS │ │base  │
└──┬───┘ └──┬───┘
   │         │
   └────┬────┘
        │
        ▼
┌─────────────────┐
│  iPhone App      │
│  1. Receive msg  │
│  2. Decrypt      │
│  3. Store in     │
│     SwiftData    │
│  4. Show in      │
│     Feed/Reader  │
└─────────────────┘
```

## Shared Config: ~/.config/markpush/

The MCP server shares the same config directory as the Go CLI.
Both can read/write `config.toml` and `devices.toml`.

```
~/.config/markpush/
├── config.toml         ← device_id, transport_mode, cloud settings
└── devices.toml        ← paired devices with encryption keys
```

This means:
- Pair once with CLI → MCP server can push too
- Pair once with MCP → CLI can push too
- No duplicate pairing needed

## npm Package: @markpush/mcp-server

### package.json
```json
{
  "name": "@markpush/mcp-server",
  "version": "0.1.0",
  "description": "MCP server for pushing AI-generated markdown to iPhone",
  "type": "module",
  "bin": {
    "markpush-mcp": "./dist/index.js"
  },
  "main": "./dist/index.js",
  "scripts": {
    "build": "tsc",
    "dev": "tsx src/index.ts",
    "test": "vitest"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.27.0",
    "zod": "^3.25.0",
    "mdns-js": "^1.0.0",
    "ws": "^8.0.0",
    "qrcode-terminal": "^0.12.0",
    "@iarna/toml": "^2.2.0"
  }
}
```

### Installation by users
```bash
# Add to Claude Code
claude mcp add markpush -- npx -y @markpush/mcp-server

# Or with environment variables
claude mcp add markpush \
  -e SUPABASE_URL=https://your-project.supabase.co \
  -e SUPABASE_KEY=your-anon-key \
  -- npx -y @markpush/mcp-server
```

## Implementation Phases

### Phase A: Core MCP scaffold (tools only)
1. Initialize TypeScript project with `@modelcontextprotocol/sdk`
2. Implement `push_markdown` tool (dry-run only)
3. Implement config store (read/write `~/.config/markpush/`)
4. Implement `list_devices` and `pair_device` tools
5. Tests with vitest

### Phase B: Transport + Crypto
1. Port AES-256-GCM encrypt from Go to TypeScript (Web Crypto API)
2. Port PBKDF2 key derivation
3. Implement WiFi transport (ws + mdns)
4. Implement cloud transport (Supabase REST)
5. Wire up `push_markdown` to real transport

### Phase C: Templates + Prompts
1. Implement prompt templates (code-review, meeting-notes, etc.)
2. Implement `push_template` tool
3. Implement `push_history` tool (local SQLite or JSON file)

### Phase D: Publish
1. Build pipeline (TypeScript → dist/)
2. npm publish `@markpush/mcp-server`
3. Update README with MCP installation instructions
4. Test end-to-end: Claude Code → MCP → iPhone

## Key Design Decisions

1. **Stdio transport** — Simplest, runs locally, no HTTP server needed, standard for npm MCP packages.
2. **Shared config** — MCP and CLI share `~/.config/markpush/` so pairing works across both.
3. **Same crypto format** — TypeScript uses Web Crypto API but produces identical nonce||ciphertext||tag layout.
4. **Same protocol** — PushMessage JSON matches the Go CLI exactly.
5. **QR pairing** — Reuses the same ephemeral HTTP + QR flow as the CLI. iOS app doesn't need changes.
