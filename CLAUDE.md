# MarkPush — Claude Code Context

## Project Summary
MarkPush is an open-source tool that pushes markdown files from the terminal
to a native iOS app over WiFi or cloud relay. Three entry points:
1. `cli/` — Go CLI tool (`markpush`)
2. `ios/` — SwiftUI iOS app (MarkPush)
3. `mcp/` — TypeScript MCP server (`@markpush/mcp-server`) — PLANNED

## System Architecture
See `docs/system-architecture.md` for full diagrams. Key flow:
```
CLI / MCP Server → AES-256-GCM encrypt → WiFi or Cloud → iOS App → Decrypt → Read
```

## Architecture
- Transport: WebSocket (local WiFi via mDNS) OR Supabase Realtime (cloud)
- Pairing: QR code + AES-256 shared key, stored in Keychain (iOS) and ~/.config/markpush/ (CLI)
- Protocol: JSON messages with base64-encoded markdown content
- Encryption: AES-256-GCM, format: nonce(12B) || ciphertext || tag(16B), then base64
- Key derivation: PBKDF2(secret, device_id, 100000, SHA-256, 32 bytes)
- iOS state: TCA (The Composable Architecture) pattern throughout
- Persistence: SwiftData models, iCloud sync enabled
- Shared config: `~/.config/markpush/` (CLI and MCP server share this)

## Key Conventions

### Go CLI
- All exported functions have godoc comments
- Error handling: always wrap with `fmt.Errorf("context: %w", err)`
- Config file: `~/.config/markpush/config.toml`
- Use `cobra` for CLI commands, `viper` for config
- Use `gorilla/websocket` for WebSocket
- Use `hashicorp/mdns` for Bonjour/mDNS
- Tests: table-driven, 80%+ coverage

### Swift/iOS
- SwiftUI everywhere, no UIKit unless absolutely necessary
- TCA pattern: Feature → Action → State → Reducer → View
- All network calls through a `MarkPushClient` dependency (injectable for testing)
- Use `async/await` throughout, never completion handlers
- Error types: typed enums conforming to `LocalizedError`
- Accessibility: every interactive element has `.accessibilityLabel`
- No hardcoded colors — use semantic color assets

### TypeScript MCP Server (planned)
- `@modelcontextprotocol/sdk` with `StdioServerTransport`
- Zod schemas for tool inputs
- Web Crypto API for AES-256-GCM (same format as Go/Swift)
- Shared config with CLI at `~/.config/markpush/`
- Tools: push_markdown, push_template, pair_device, list_devices, push_history

## Directory Structure
```
markpush/
├── cli/              ← Go CLI tool
│   ├── cmd/          ← cobra commands (root, push, pair, watch, history, config)
│   ├── internal/     ← transport/, mdns/, crypto/, config/, protocol/, history/
│   └── pkg/qr/      ← QR code generation
├── ios/              ← SwiftUI iOS app
│   └── MarkPush/
│       ├── App/      ← entry point + TCA root
│       ├── Features/ ← Feed, Reader, Library, Pairing, Settings
│       ├── Models/   ← SwiftData models
│       ├── Clients/  ← TCA dependencies
│       ├── Transport/← WiFi + Cloud receivers
│       └── UI/       ← Theme, components, assets
├── mcp/              ← TypeScript MCP server (planned)
│   └── src/          ← tools/, prompts/, transport/, crypto/
├── relay/            ← Self-hostable Supabase cloud relay
├── docs/             ← Architecture, API contracts, protocols
└── scripts/          ← Install, dev-setup, release
```

## Running Locally

### CLI
```bash
cd cli && go run . --help
go test ./... -race
```

### iOS
Open `ios/MarkPush.xcodeproj` in Xcode 16+
Select a simulator or device and run.

## Current Status
Phase 1: CLI Tool ✅
Phase 2: WiFi Transport ✅
Phase 3: iOS App ✅ (source complete, needs Xcode project setup)
Phase 4: Cloud Relay ✅
Phase 5: Power Features ✅ (watch mode, library)
Phase 6: OSS Packaging ✅
**Next: MCP Server** — see `docs/mcp-server-plan.md`

## Key Docs
- `docs/system-architecture.md` — Full system diagrams
- `docs/mcp-server-plan.md` — MCP server implementation plan
- `docs/architecture.md` — Transport and security architecture
- `docs/api-contracts.md` — JSON message schemas
- `docs/pairing-protocol.md` — QR pairing flow
- `docs/self-hosting.md` — Supabase self-hosting guide

## Do Not
- Do not use UIKit for new UI code
- Do not use Combine (use async/await + AsyncStream)
- Do not use UserDefaults for sensitive data (use Keychain)
- Do not hardcode any API keys or credentials
- Do not commit .env files
