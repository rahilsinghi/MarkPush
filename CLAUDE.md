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
├── mcp/              ← TypeScript MCP server (@markpush/mcp-server)
│   └── src/          ← tools/, prompts/, transport/, crypto/
├── relay/            ← Self-hostable Supabase cloud relay
├── design/           ← App icon, logo, UI palette, mockups, onboarding
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
```bash
# Generate project (after modifying project.yml)
cd ios && xcodegen generate

# Open in Xcode
open -a Xcode ios/MarkPush.xcodeproj

# Or build from CLI
xcodebuild build -project ios/MarkPush.xcodeproj -scheme MarkPush \
  -destination 'platform=iOS Simulator,name=iPhone 16e'
```

### MCP Server
```bash
cd mcp && npm test     # run tests
cd mcp && npm run dev  # run locally
```

## Xcode Setup Notes (IMPORTANT — learned from experience)
- **xcodegen** generates .xcodeproj from `ios/project.yml` — run `cd ios && xcodegen generate` after changes
- **SPM product names** must be explicit in project.yml: `package: swift-composable-architecture, product: ComposableArchitecture`
- **Swift concurrency**: set `SWIFT_STRICT_CONCURRENCY: targeted` (not `complete`) — KeychainAccess and other deps don't support strict Sendable
- **KeychainAccess**: use `@preconcurrency import KeychainAccess` and `nonisolated(unsafe)` for static properties
- **UIDevice.current.name** is `@MainActor` in iOS 26 — must use `await`
- **Info.plist MUST include** CFBundleIdentifier, CFBundleExecutable, etc. or simulator fails with "Missing bundle ID"
- **No multicast entitlement** with free Personal Team — remove from entitlements
- **No App Sandbox** entitlement on iOS (macOS only)
- **ModelContainer** init should be explicit `try` in App init, not inline `.modelContainer(for:)`
- **TCA sheet bindings**: use `Binding(get:set:)` pattern, not `$store.property` for non-@BindingState properties
- **`.accent` is not a ShapeStyle** — use `.tint` instead
- After cleaning DerivedData, must re-resolve packages: `File → Packages → Resolve Package Versions`
- **Supabase Auth**: set `SupabaseURL` and `SupabaseAnonKey` in `ios/MarkPush/Info.plist` before running
- **Magic link deep links**: URL scheme `markpush://` registered in Info.plist, handled via `.onOpenURL` in MarkPushApp
- **SupabaseClient is Sendable** — no need for `nonisolated(unsafe)` wrapper (unlike KeychainAccess)

## Current Status
Phase 1: CLI Tool ✅
Phase 2: WiFi Transport ✅
Phase 3: iOS App ✅ (running on simulator)
Phase 4: Cloud Relay ✅
Phase 5: Power Features ✅
Phase 6: OSS Packaging ✅
MCP Server ✅ (6 tools, 4 prompts, 32 tests passing)
Design System ✅ (custom fonts, semantic colors, typography, spacing)
Supabase Auth Backend ✅ (beta_whitelist, profiles, devices, push_tokens, RLS)
iOS Auth Flow ✅ (AuthClient, AuthFeature, magic link login, deep links, sign out)
E2E Backend Tests ✅ (33 SQL assertions: schema, RLS dual-path, profiles, devices, whitelist, tokens)
E2E iOS Tests ✅ (40 TCA tests: Auth 13, Settings 8, App 4, Library 5, Feed 3, Pairing 3, Reader 4)
Supabase Live ✅ (migrations applied, rahilsinghi300@gmail.com whitelisted, redirect URLs configured)
**Next:** Manual testing (magic link flow, QR pairing, push delivery), npm publish MCP, TestFlight beta

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
