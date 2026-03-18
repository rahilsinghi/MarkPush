# MarkPush — Claude Code Context

## Project Summary
MarkPush is an open-source tool that pushes markdown files from the terminal
to a native iOS app over WiFi or cloud relay. Three entry points:
1. `cli/` — Go CLI tool (`markpush`)
2. `ios/` — SwiftUI iOS app (MarkPush)
3. `mcp/` — TypeScript MCP server (`@markpush/mcp-server`) — PUBLISHED on npm

## System Architecture
See `docs/system-architecture.md` for full diagrams. Key flow:
```
CLI / MCP Server → AES-256-GCM encrypt → WiFi or Cloud → iOS App → Decrypt → Read
```

## Architecture
- Transport: Raw TCP (local WiFi via mDNS) OR Supabase Realtime (cloud)
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
- WiFi transport uses raw TCP (not WebSocket) — NWProtocolWebSocket handshake fails with gorilla/websocket
- WiFi listener uses `.any` port (OS-assigned) — CLI discovers via mDNS, avoids "Address already in use" on restart
- Use `hashicorp/mdns` for Bonjour/mDNS (note: can't discover simulator, works on real devices)
- Cloud transport includes `user_id` for RLS-compliant Supabase Realtime routing
- Tests: table-driven, 80%+ coverage

### Swift/iOS
- SwiftUI everywhere, no UIKit unless absolutely necessary
- TCA pattern: Feature → Action → State → Reducer → View
- All network calls through a `MarkPushClient` dependency (injectable for testing)
- Use `async/await` throughout, never completion handlers
- Error types: typed enums conforming to `LocalizedError`
- Accessibility: every interactive element has `.accessibilityLabel`
- No hardcoded colors — use semantic color assets

### TypeScript MCP Server (published: @markpush/mcp-server@0.1.0)
- `@modelcontextprotocol/sdk` with `StdioServerTransport`
- Zod schemas for tool inputs
- Web Crypto API for AES-256-GCM (same format as Go/Swift)
- Shared config with CLI at `~/.config/markpush/`
- Tools: push_markdown, push_template, pair_device, unpair_device, list_devices, push_history
- Install: `claude mcp add markpush -- npx -y @markpush/mcp-server`
- npm org: `@markpush` (owner: rahil2704)

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
- **Supabase session warning**: set `emitLocalSessionAsInitialSession: true` in SupabaseClient options to suppress SDK warning
- **Magic link deep links**: URL scheme `markpush://` registered in Info.plist, handled via `.onOpenURL` in MarkPushApp
- **SupabaseClient is Sendable** — no need for `nonisolated(unsafe)` wrapper (unlike KeychainAccess)
- **WiFiReceiver actor lifetime**: must store in `nonisolated(unsafe) var` — local variable gets deallocated after `startReceiving` returns, killing the listener
- **Go RFC3339Nano timestamps**: Swift `.iso8601` can't parse fractional seconds — use custom decoder with `.withFractionalSeconds`
- **OTP verify type**: use `.magiclink` (not `.email`) when `signInWithOTP(redirectTo:)` was called
- **Supabase OTP length**: 8 digits by default (configurable in dashboard), iOS accepts 4-8
- **Supabase email template**: must include `{{ .Token }}` for OTP code — default only shows magic link
- **Cloud Realtime RLS**: filter by `user_id` (not `receiver_id`) for authenticated iOS clients
- **SharedModelContainer**: singleton `ModelContainer` shared between app views and TCA PersistenceClient
- **New files after changes**: run `cd ios && xcodegen generate` to include them in the Xcode project
- **Xcode beta path**: may be at `/Users/rahilsinghi/Downloads/Xcode-beta.app` — use `sudo xcode-select -s` to switch
- **iOS 26 Liquid Glass**: NavigationStack toolbar gets automatic system buttons (sidebar toggle "..."). Fix: use custom header + `.navigationBarHidden(true)` on root views
- **Custom font + .fontWeight()**: Don't apply `.fontWeight()` to custom fonts with weight baked into the name (e.g. `Lora-SemiBold`). Swap font faces instead
- **Portrait-only**: Must set `UIRequiresFullScreen = true` in Info.plist if only supporting portrait orientation

## Current Status
Phase 1: CLI Tool ✅
Phase 2: WiFi Transport ✅
Phase 3: iOS App ✅ (running on simulator + physical device)
Phase 4: Cloud Relay ✅
Phase 5: Power Features ✅
Phase 6: OSS Packaging ✅
MCP Server ✅ (6 tools, 4 prompts, 32 tests passing)
Design System ✅ (custom fonts, semantic colors, typography, spacing)
Supabase Auth Backend ✅ (beta_whitelist, profiles, devices, push_tokens, RLS)
iOS Auth Flow ✅ (AuthClient, AuthFeature, magic link login, deep links, sign out)
E2E Backend Tests ✅ (33 SQL assertions: schema, RLS dual-path, profiles, devices, whitelist, tokens)
E2E iOS Tests ✅ (50 TCA tests: Auth 23, Settings 8, App 4, Library 5, Feed 3, Pairing 3, Reader 4)
Supabase Live ✅ (migrations applied, rahilsinghi300@gmail.com whitelisted, redirect URLs configured)
OTP Code Entry ✅ (code fallback when magic link deep link doesn't work, accepts 4-8 digits)
Beta Whitelist Enforcement ✅ (non-whitelisted users signed out after auth, shown beta access screen)
WiFi E2E ✅ (CLI → raw TCP → iOS Feed → Reader with MarkdownUI → Library with SwiftData)
Cloud E2E ✅ (CLI → Supabase REST → iOS Realtime → Feed, user_id routing)
Feed → Reader Navigation ✅ (tap to open, full markdown rendering with code blocks, tables, tags)
SwiftData Persistence ✅ (PersistenceClient, SharedModelContainer, documents in Library)
Session Persistence ✅ (30-day re-auth via Keychain + UserDefaults lastAuthDate)
npm Published ✅ (@markpush/mcp-server@0.1.0, public, MIT)
Physical Device ✅ (iPhone 17 Pro: auth, pairing, cloud push all verified)
MCP Live ✅ (local source, cloud push to physical device working)
**Next:** Test WiFi push on device, Feed→Reader→Library flow, MCP templates, paid Apple Developer → TestFlight, new PRD (dual-mode)

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
