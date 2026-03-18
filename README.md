# MarkPush

**Push markdown from your terminal to your iPhone. One command. Instant delivery.**

> You vibe code all day. Claude generates docs, code reviews, meeting notes. But reading markdown in a terminal sucks. MarkPush sends it to your phone — encrypted, instant, beautiful.

[![npm](https://img.shields.io/npm/v/@markpush/mcp-server)](https://www.npmjs.com/package/@markpush/mcp-server)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## How It Works

```
 You (vibe coding)              Your iPhone
 ─────────────────              ───────────

 Claude generates a doc         MarkPush app
        │                            ▲
        ▼                            │
  markpush push doc.md ──────► AES-256-GCM encrypted
        │                            │
   ┌────┴────┐                  ┌────┴────┐
   │  WiFi   │                  │  Cloud  │
   │ (local) │                  │(remote) │
   └─────────┘                  └─────────┘
   mDNS auto-                  Supabase Realtime
   discovery                    (self-hostable)
```

**Three ways to push:**

| Method | Command | Best for |
|--------|---------|----------|
| CLI | `markpush push file.md` | Quick pushes from terminal |
| Pipe | `cat output.md \| markpush push --stdin` | Chaining with other tools |
| MCP | Claude pushes directly via MCP server | AI-generated content |

## The Personal Use Flow

**For developers who vibe code with AI and want to read the output comfortably.**

```
1. Clone this repo
2. Build the iOS app in Xcode (free, no Apple Developer fee needed)
3. Install the CLI
4. Pair your phone (one-time QR scan)
5. Start pushing — every AI output lands on your phone instantly
```

The app stays on your phone permanently. No TestFlight. No App Store. Just build once and use forever.

## Quick Start

### 1. Build the iOS App

```bash
# Prerequisites: Xcode 16+, xcodegen (brew install xcodegen)
git clone https://github.com/rahilsinghi/MarkPush.git
cd MarkPush/ios && xcodegen generate
open MarkPush.xcodeproj
```

In Xcode:
- Set your **Team** in Signing & Capabilities (free Personal Team works)
- Connect your iPhone or select a simulator
- **Cmd+R** to build and run

> The app uses Supabase for cloud relay and auth. See [self-hosting guide](docs/self-hosting.md) to set up your own instance, or use the default for testing.

### 2. Install the CLI

```bash
# From source
cd cli && go install .

# Or run directly
cd cli && go run . --help
```

### 3. Pair Your Devices

```bash
markpush pair
# Scan the QR code with the MarkPush iOS app → Settings → Pair New Device
# Done — devices are paired with end-to-end encryption
```

### 4. Push Your First Document

```bash
markpush push README.md
# Check your phone — it's there.
```

## MCP Server (for Claude Code / AI agents)

Let Claude push documents directly to your phone:

```bash
# One-line install for Claude Code
claude mcp add markpush -- npx -y @markpush/mcp-server
```

Then in any Claude conversation:

> *"Push this code review to my phone"*
> *"Send the meeting notes to MarkPush"*
> *"Push a summary of this PR to my iPhone"*

The MCP server includes templates for common AI outputs: code reviews, meeting notes, daily summaries, and bug reports.

```bash
# Published on npm
npm install -g @markpush/mcp-server
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    SENDER SIDE                          │
│                                                         │
│  ┌──────────┐   ┌──────────────┐   ┌────────────────┐  │
│  │  Go CLI  │   │  MCP Server  │   │  Any client    │  │
│  │          │   │  (TypeScript)│   │  using the     │  │
│  │ markpush │   │  @markpush/  │   │  protocol      │  │
│  │ push     │   │  mcp-server  │   │                │  │
│  └────┬─────┘   └──────┬───────┘   └───────┬────────┘  │
│       │                │                    │           │
│       └────────┬───────┴────────────────────┘           │
│                │                                        │
│         ┌──────▼───────┐                                │
│         │  AES-256-GCM │  PBKDF2(secret, device_id)     │
│         │  Encryption  │  nonce(12B) || ct || tag(16B)   │
│         └──────┬───────┘                                │
│                │                                        │
│         ┌──────┴──────┐                                 │
│         │             │                                 │
│    ┌────▼────┐  ┌─────▼─────┐                           │
│    │  WiFi   │  │   Cloud   │                           │
│    │Raw TCP  │  │ Supabase  │                           │
│    │+ mDNS   │  │ Realtime  │                           │
│    └────┬────┘  └─────┬─────┘                           │
└─────────┼─────────────┼─────────────────────────────────┘
          │             │
          │   network   │
          │             │
┌─────────┼─────────────┼─────────────────────────────────┐
│         │  RECEIVER   │                                 │
│    ┌────▼────┐  ┌─────▼─────┐                           │
│    │  WiFi   │  │   Cloud   │                           │
│    │Receiver │  │ Receiver  │                           │
│    └────┬────┘  └─────┬─────┘                           │
│         │             │                                 │
│         └──────┬──────┘                                 │
│                │                                        │
│         ┌──────▼───────┐                                │
│         │  AES-256-GCM │                                │
│         │  Decryption  │                                │
│         └──────┬───────┘                                │
│                │                                        │
│    ┌───────────┼───────────────┐                        │
│    │           │               │                        │
│  ┌─▼──┐   ┌───▼───┐   ┌──────▼──┐                      │
│  │Feed│   │Reader │   │Library  │                      │
│  │    │──▶│       │──▶│SwiftData│                      │
│  └────┘   └───────┘   └─────────┘                      │
│                                                         │
│              iOS App (SwiftUI + TCA)                    │
└─────────────────────────────────────────────────────────┘
```

## Features

- **Instant delivery** — WiFi transport auto-discovers your phone via Bonjour (zero config)
- **End-to-end encrypted** — AES-256-GCM with PBKDF2 key derivation, keys never leave your devices
- **Works anywhere** — Local WiFi for home, cloud relay for remote (self-hostable)
- **Beautiful reader** — Custom typography (Fraunces, Lora, Inter), syntax highlighting, tables, code blocks
- **MCP integration** — Claude pushes content directly via the published npm package
- **Watch mode** — `markpush watch ./docs/` pushes on every file save
- **Pipe-friendly** — `cat output.md | markpush push --stdin`
- **Library** — All pushed documents saved locally with SwiftData, searchable
- **QR pairing** — One-time secure pairing, credentials stored in Keychain

## Tech Stack

| Layer | Technology |
|-------|-----------|
| CLI | Go, Cobra, Viper |
| MCP Server | TypeScript, `@modelcontextprotocol/sdk` |
| Local transport | Raw TCP + mDNS (Bonjour) |
| Cloud relay | Supabase Realtime + RLS |
| Auth | Supabase OTP (magic link) |
| iOS app | Swift, SwiftUI, TCA |
| Markdown rendering | swift-markdown-ui + Splash |
| Encryption | AES-256-GCM (CryptoKit / Web Crypto / Go crypto) |
| Persistence | SwiftData |
| Design | Custom fonts, semantic colors, accessibility |

## Project Structure

```
markpush/
├── cli/              ← Go CLI (push, pair, watch, history, config)
├── ios/              ← SwiftUI iOS app (TCA architecture)
│   └── MarkPush/
│       ├── Features/ ← Feed, Reader, Library, Pairing, Settings, Auth
│       ├── Transport/← WiFi + Cloud receivers
│       └── UI/       ← Design system (fonts, colors, components)
├── mcp/              ← MCP server (npm: @markpush/mcp-server)
├── relay/            ← Supabase cloud relay (self-hostable)
├── design/           ← App icon, logo, mockups
├── docs/             ← Architecture, API contracts, protocols
└── scripts/          ← Install & dev scripts
```

## Development

### Prerequisites

- Go 1.22+
- Xcode 16+ with iOS 17+ SDK
- Node.js 18+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### CLI

```bash
cd cli && go run . --help
go test ./... -race
```

### iOS App

```bash
cd ios && xcodegen generate
open MarkPush.xcodeproj
# Set your Team in Signing & Capabilities → Cmd+R
```

### MCP Server

```bash
cd mcp && npm install && npm test
cd mcp && npm run dev  # run locally
```

## Security

- All content is encrypted end-to-end with **AES-256-GCM**
- Keys are derived using **PBKDF2** (100,000 iterations, SHA-256)
- Encryption keys are stored in the iOS **Keychain** and `~/.config/markpush/` on desktop
- The cloud relay only sees encrypted payloads — it cannot read your content
- Supabase RLS ensures users only receive their own messages

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT — see [LICENSE](LICENSE) for details.

---

Built by [@rahilsinghi](https://github.com/rahilsinghi). Star the repo if you find it useful.
