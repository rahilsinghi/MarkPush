# MarkPush — Full Implementation Plan
> Push AI-generated markdown from your terminal to a beautiful iOS reader. One command. Instant delivery.

**Status:** Open Source · MIT License  
**Repo name suggestion:** `markpush`  
**Tagline:** *"Pocket for your AI outputs."*

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Claude Code Setup — Optimal Configuration](#2-claude-code-setup--optimal-configuration)
3. [Repository Structure](#3-repository-structure)
4. [Phase 1 — CLI Tool (Go)](#4-phase-1--cli-tool-go)
5. [Phase 2 — Local WiFi Transport](#5-phase-2--local-wifi-transport)
6. [Phase 3 — iOS App (Swift/SwiftUI)](#6-phase-3--ios-app-swiftswiftui)
7. [Phase 4 — Cloud Relay](#7-phase-4--cloud-relay)
8. [Phase 5 — Power Features](#8-phase-5--power-features)
9. [Phase 6 — Open Source Packaging](#9-phase-6--open-source-packaging)
10. [iOS UI/UX Design Spec](#10-ios-uiux-design-spec)
11. [API Contracts](#11-api-contracts)
12. [Testing Strategy](#12-testing-strategy)
13. [Claude Code Prompts — Session Starters](#13-claude-code-prompts--session-starters)

---

## 1. Project Overview

### What We're Building

```
Terminal (Claude/AI output)
         │
         ▼
   markpush [file.md]          ← Single CLI command
         │
    ┌────┴────┐
    │         │
  WiFi      Cloud
 (local)   (remote)
    │         │
    └────┬────┘
         ▼
    iPhone App
  Beautiful Reader
```

### Tech Stack Decision Matrix

| Layer | Choice | Rationale |
|---|---|---|
| CLI tool | **Go** | Single binary, cross-platform, fast startup, easy distribution |
| Local transport | **WebSocket + mDNS (Bonjour)** | Zero-config discovery, native to Apple ecosystem |
| Cloud relay | **Supabase Realtime** | Free tier generous, Postgres-backed, real-time subscriptions, easy self-host |
| iOS App | **Swift + SwiftUI** | Native performance, best iOS feel, proper markdown rendering |
| Markdown rendering | **swift-markdown-ui** | Full CommonMark + GFM, composable, customizable themes |
| Syntax highlighting | **Splash** (by John Sundell) | Native Swift, no JS, fast |
| Auth/pairing | **QR code + AES-256 shared key** | Scan once, done, offline-capable |
| State management | **TCA (The Composable Architecture)** | Predictable, testable, scales well |
| Persistence (iOS) | **SwiftData** | Modern, Swift-native, syncs with iCloud |
| Package manager | **Swift Package Manager** for iOS, **Go modules** for CLI |

---

## 2. Claude Code Setup — Optimal Configuration

### Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
cd markpush
claude
```

### `.claude/settings.json` — Project Config

Create this file at the root of your repo:

```json
{
  "model": "claude-opus-4-5",
  "context": {
    "include": [
      "CLAUDE.md",
      "docs/architecture.md",
      "docs/api-contracts.md"
    ]
  },
  "tools": {
    "bash": true,
    "computer": false,
    "text_editor": true
  },
  "permissions": {
    "allow": [
      "Bash(go build:*)",
      "Bash(go test:*)",
      "Bash(go run:*)",
      "Bash(swift build:*)",
      "Bash(xcodebuild:*)",
      "Bash(git:*)",
      "Bash(brew install:*)",
      "Bash(npm:*)"
    ]
  }
}
```

### `CLAUDE.md` — The Most Important File

This is the memory file Claude Code reads at the start of every session. Put it in the repo root.

```markdown
# MarkPush — Claude Code Context

## Project Summary
MarkPush is an open-source tool that pushes markdown files from the terminal
to a native iOS app over WiFi or cloud relay. Two components:
1. `cli/` — Go CLI tool (`markpush`)
2. `ios/` — SwiftUI iOS app (MarkPush)

## Architecture
- Transport: WebSocket (local WiFi via mDNS) OR Supabase Realtime (cloud)
- Pairing: QR code + AES-256 shared key, stored in Keychain (iOS) and ~/.config/markpush/ (CLI)
- Protocol: JSON messages with base64-encoded markdown content
- iOS state: TCA (The Composable Architecture) pattern throughout
- Persistence: SwiftData models, iCloud sync enabled

## Key Conventions

### Go CLI
- All exported functions have godoc comments
- Error handling: always wrap with `fmt.Errorf("context: %w", err)`
- Config file: `~/.config/markpush/config.toml`
- Use `cobra` for CLI commands, `viper` for config
- Use `gorilla/websocket` for WebSocket
- Use `grandcentral` (or `_mdns`) for Bonjour/mDNS

### Swift/iOS
- SwiftUI everywhere, no UIKit unless absolutely necessary
- TCA pattern: Feature → Action → State → Reducer → View
- All network calls through a `MarkPushClient` dependency (injectable for testing)
- Use `async/await` throughout, never completion handlers
- Error types: typed enums conforming to `LocalizedError`
- Accessibility: every interactive element has `.accessibilityLabel`
- No hardcoded colors — use semantic color assets (`MarkPushColors.xcassets`)

## Directory Structure
See README.md for full tree.

## Running Locally
### CLI
```bash
cd cli && go run . --help
go test ./...
```

### iOS
Open `ios/MarkPush.xcodeproj` in Xcode 16+
Select a simulator or device and run.

## Current Phase
[Update this as you progress]
Phase 1: CLI Tool ← YOU ARE HERE

## Do Not
- Do not use UIKit for new UI code
- Do not use Combine (use async/await + AsyncStream)
- Do not use UserDefaults for sensitive data (use Keychain)
- Do not hardcode any API keys or credentials
- Do not commit .env files
```

### MCP Servers to Enable

Install these MCP servers in Claude Code for maximum power:

```bash
# 1. GitHub MCP — manage issues, PRs, releases from within Claude Code
claude mcp add github -- npx -y @modelcontextprotocol/server-github

# 2. Filesystem — extended file operations
claude mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem /path/to/markpush

# 3. Fetch — fetch docs, read Swift Package Index, read Supabase docs
claude mcp add fetch -- npx -y @modelcontextprotocol/server-fetch

# 4. Xcode Build Server (community) — get build errors, run tests
# Install xcbeautify for nicer build output
brew install xcbeautify

# 5. Sequential Thinking — for complex architecture decisions
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
```

### Recommended `.env` (never commit)

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
MARKPUSH_DEV_DEVICE_ID=your-test-device-id
```

### Recommended VS Code Extensions (for the Go side)

```json
{
  "recommendations": [
    "golang.go",
    "ms-vscode.makefile-tools",
    "mtxr.sqltools",
    "ms-azuretools.vscode-docker",
    "eamodio.gitlens",
    "usernamehw.errorlens",
    "streetsidesoftware.code-spell-checker"
  ]
}
```

### Xcode Setup

- **Xcode 16+** required (SwiftData + Swift 6 concurrency)
- Enable strict concurrency checking: Build Settings → `SWIFT_STRICT_CONCURRENCY = complete`
- Enable SwiftUI Previews in macro-powered environments
- Install **SwiftLint** via Homebrew and add a build phase
- Install **SwiftFormat** for consistent formatting

```bash
brew install swiftlint swiftformat
```

Add to Xcode Build Phases (Run Script):
```bash
if which swiftlint > /dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
```

---

## 3. Repository Structure

```
markpush/
├── CLAUDE.md                      ← Claude Code memory file (critical)
├── README.md
├── LICENSE                        ← MIT
├── CONTRIBUTING.md
├── CHANGELOG.md
├── Makefile                       ← Top-level build orchestration
│
├── cli/                           ← Go CLI tool
│   ├── go.mod
│   ├── go.sum
│   ├── main.go
│   ├── cmd/
│   │   ├── root.go                ← cobra root command
│   │   ├── push.go                ← `markpush push [file]`
│   │   ├── pair.go                ← `markpush pair`
│   │   ├── history.go             ← `markpush history`
│   │   ├── watch.go               ← `markpush watch [dir]`
│   │   └── config.go              ← `markpush config`
│   ├── internal/
│   │   ├── transport/
│   │   │   ├── transport.go       ← Transport interface
│   │   │   ├── wifi.go            ← WiFi/WebSocket transport
│   │   │   └── cloud.go           ← Supabase Realtime transport
│   │   ├── mdns/
│   │   │   └── discover.go        ← mDNS device discovery
│   │   ├── crypto/
│   │   │   └── aes.go             ← AES-256-GCM encryption
│   │   ├── config/
│   │   │   └── config.go          ← Viper config management
│   │   ├── protocol/
│   │   │   └── message.go         ← Shared message types (JSON)
│   │   └── history/
│   │       └── history.go         ← Local push history (SQLite)
│   └── pkg/
│       └── qr/
│           └── qr.go              ← QR code generation (terminal)
│
├── ios/                           ← SwiftUI iOS app
│   ├── MarkPush.xcodeproj/
│   ├── MarkPush/
│   │   ├── App/
│   │   │   ├── MarkPushApp.swift
│   │   │   └── AppReducer.swift   ← TCA root reducer
│   │   ├── Features/
│   │   │   ├── Feed/              ← Live incoming docs
│   │   │   │   ├── FeedFeature.swift
│   │   │   │   └── FeedView.swift
│   │   │   ├── Reader/            ← Full-screen markdown reader
│   │   │   │   ├── ReaderFeature.swift
│   │   │   │   └── ReaderView.swift
│   │   │   ├── Library/           ← All received docs
│   │   │   │   ├── LibraryFeature.swift
│   │   │   │   └── LibraryView.swift
│   │   │   ├── Pairing/           ← QR scan + device pairing
│   │   │   │   ├── PairingFeature.swift
│   │   │   │   └── PairingView.swift
│   │   │   └── Settings/
│   │   │       ├── SettingsFeature.swift
│   │   │       └── SettingsView.swift
│   │   ├── Models/
│   │   │   ├── MarkDocument.swift ← SwiftData model
│   │   │   ├── Device.swift       ← Paired device model
│   │   │   └── Annotation.swift   ← User highlights/notes
│   │   ├── Clients/
│   │   │   ├── MarkPushClient.swift        ← TCA dependency
│   │   │   ├── MarkPushClientLive.swift    ← Real implementation
│   │   │   └── MarkPushClientMock.swift    ← Test mock
│   │   ├── Transport/
│   │   │   ├── WiFiReceiver.swift
│   │   │   └── CloudReceiver.swift
│   │   ├── UI/
│   │   │   ├── MarkdownView.swift  ← Custom markdown renderer wrapper
│   │   │   ├── Theme.swift         ← Typography + colors
│   │   │   ├── Components/
│   │   │   │   ├── DocCard.swift
│   │   │   │   ├── TOCDrawer.swift
│   │   │   │   └── TagPill.swift
│   │   │   └── Assets.xcassets/
│   │   └── Utilities/
│   │       ├── Keychain.swift
│   │       └── NotificationManager.swift
│   └── MarkPushTests/
│
├── relay/                         ← Optional self-hostable cloud relay
│   ├── README.md
│   └── supabase/
│       ├── migrations/
│       │   └── 001_init.sql
│       └── functions/
│           └── relay/
│               └── index.ts
│
├── docs/
│   ├── architecture.md
│   ├── api-contracts.md
│   ├── pairing-protocol.md
│   └── self-hosting.md
│
├── .github/
│   ├── workflows/
│   │   ├── ci-cli.yml             ← Go test + build
│   │   ├── ci-ios.yml             ← Xcode build + test
│   │   └── release.yml            ← GoReleaser + App Store
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   └── pull_request_template.md
│
├── scripts/
│   ├── install.sh                 ← One-line install script
│   ├── dev-setup.sh               ← Developer environment setup
│   └── release.sh
│
└── Makefile
```

---

## 4. Phase 1 — CLI Tool (Go)

### Goal
Working CLI that reads a markdown file and prints what it *would* send (dry run). Sets up the full command structure.

### Dependencies

```toml
# go.mod
require (
    github.com/spf13/cobra v1.8.1
    github.com/spf13/viper v1.19.0
    github.com/gorilla/websocket v1.5.3
    github.com/grandcentral/mdns v0.0.0    # or hashicorp/mdns
    github.com/skip2/go-qrcode v0.0.0
    github.com/charmbracelet/lipgloss v0.13.0  # terminal styling
    github.com/charmbracelet/bubbletea v1.1.0  # interactive TUI (pairing flow)
    github.com/mattn/go-sqlite3 v1.14.23       # history DB
    github.com/BurntSushi/toml v1.4.0
    golang.org/x/crypto v0.28.0               # AES-256-GCM
)
```

### Core Protocol Message

```go
// internal/protocol/message.go

package protocol

import "time"

const (
    MessageTypePush      = "push"
    MessageTypePairInit  = "pair_init"
    MessageTypePairAck   = "pair_ack"
    MessageTypePing      = "ping"
    MessageTypePong      = "pong"
)

// PushMessage is the primary payload sent from CLI to iOS app.
type PushMessage struct {
    // Header
    Version   string    `json:"version"`            // protocol version, e.g. "1"
    Type      string    `json:"type"`               // "push"
    ID        string    `json:"id"`                 // UUID v4
    Timestamp time.Time `json:"timestamp"`

    // Metadata
    Title     string   `json:"title"`               // inferred from first H1 or filename
    Tags      []string `json:"tags,omitempty"`
    Source    string   `json:"source,omitempty"`    // e.g. "claude", "cursor", "manual"
    WordCount int      `json:"word_count"`

    // Content (AES-256-GCM encrypted if paired with key)
    Content   string `json:"content"`               // base64-encoded markdown
    Encrypted bool   `json:"encrypted"`

    // Device
    SenderID   string `json:"sender_id"`            // CLI device UUID
    SenderName string `json:"sender_name"`          // hostname
}
```

### CLI Commands

```go
// cmd/push.go — the main command

var pushCmd = &cobra.Command{
    Use:   "push [file]",
    Short: "Push a markdown file to your iPhone",
    Long: `Push a markdown file to your paired iPhone over WiFi or cloud relay.
    
Examples:
  markpush push README.md
  markpush push --title "Auth Design" --tag backend architecture.md
  cat output.md | markpush push --stdin
  markpush push --watch ./docs/     # watch directory, push on change
`,
    RunE: runPush,
}

func init() {
    pushCmd.Flags().String("title", "", "Override document title")
    pushCmd.Flags().StringSlice("tag", []string{}, "Tags for the document (repeatable)")
    pushCmd.Flags().Bool("stdin", false, "Read from stdin instead of file")
    pushCmd.Flags().Bool("wifi", false, "Force WiFi transport")
    pushCmd.Flags().Bool("cloud", false, "Force cloud transport")
    pushCmd.Flags().Bool("dry-run", false, "Print what would be sent, don't send")
    pushCmd.Flags().String("source", "", "Source tag (e.g. 'claude', 'cursor')")
    rootCmd.AddCommand(pushCmd)
}
```

### mDNS Discovery

```go
// internal/mdns/discover.go

package mdns

import (
    "context"
    "time"
)

const ServiceType = "_markpush._tcp"
const ServiceDomain = "local."

type Device struct {
    Name    string
    Host    string
    Port    int
    ID      string // from TXT record
}

// Discover finds MarkPush iOS apps on the local network.
// Returns first device found within timeout, or error.
func Discover(ctx context.Context, timeout time.Duration) (*Device, error) {
    // Use github.com/hashicorp/mdns
    // Publish query for _markpush._tcp.local.
    // Parse TXT records for device ID to match against paired device
}

// Advertise publishes the CLI as a sender on the network (optional, for bidirectional)
func Advertise(ctx context.Context, deviceID string, port int) error {
    // ...
}
```

### Encryption

```go
// internal/crypto/aes.go

package crypto

import (
    "crypto/aes"
    "crypto/cipher"
    "crypto/rand"
    "encoding/base64"
    "fmt"
    "io"
)

// Encrypt encrypts plaintext with AES-256-GCM.
// key must be 32 bytes. Returns base64-encoded ciphertext.
func Encrypt(key []byte, plaintext []byte) (string, error) {
    block, err := aes.NewCipher(key)
    if err != nil {
        return "", fmt.Errorf("create cipher: %w", err)
    }
    gcm, err := cipher.NewGCM(block)
    if err != nil {
        return "", fmt.Errorf("create GCM: %w", err)
    }
    nonce := make([]byte, gcm.NonceSize())
    if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
        return "", fmt.Errorf("generate nonce: %w", err)
    }
    ciphertext := gcm.Seal(nonce, nonce, plaintext, nil)
    return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// Decrypt decrypts base64-encoded AES-256-GCM ciphertext.
func Decrypt(key []byte, encoded string) ([]byte, error) {
    // inverse of Encrypt
}

// DeriveKey derives a 32-byte key from a pairing secret using PBKDF2.
func DeriveKey(secret string, salt []byte) []byte {
    // golang.org/x/crypto/pbkdf2
}
```

### Pairing Flow (CLI side)

```go
// cmd/pair.go

// markpush pair
// 1. Generate a random 32-byte pairing secret
// 2. Encode as QR code in the terminal (using go-qrcode + lipgloss)
// 3. Start a local HTTP server on a random port
// 4. Wait for iOS app to scan QR, POST to /pair with device info
// 5. On success: save device info + shared key to ~/.config/markpush/devices.toml
// 6. Show success with device name

// QR code payload (JSON):
type PairingPayload struct {
    Version   string `json:"v"`
    Secret    string `json:"s"`    // base64 random 32 bytes
    Host      string `json:"h"`   // CLI machine's local IP
    Port      int    `json:"p"`   // ephemeral pairing server port
    SenderID  string `json:"id"`
    SenderName string `json:"name"` // hostname
}
```

### Makefile targets

```makefile
# Makefile (cli section)
.PHONY: build test lint install

build:
	cd cli && go build -ldflags="-s -w -X main.version=$(VERSION)" -o ../bin/markpush .

test:
	cd cli && go test ./... -race -coverprofile=coverage.out

lint:
	cd cli && golangci-lint run

install:
	cd cli && go install .

# Install script via Homebrew tap (Phase 6)
brew-tap:
	# Creates homebrew-markpush tap repo with formula
```

---

## 5. Phase 2 — Local WiFi Transport

### Server (iOS App side — receives)

The iOS app runs a tiny WebSocket server using `Network.framework`:

```swift
// Transport/WiFiReceiver.swift

import Network
import Foundation

actor WiFiReceiver {
    private var listener: NWListener?
    private let port: NWEndpoint.Port = 49152  // registered port range
    
    // Publishes received PushMessage values
    var messages: AsyncStream<PushMessage> { get }
    
    func start() async throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        listener = try NWListener(using: parameters, on: port)
        
        // Advertise via Bonjour so CLI can find us
        listener?.service = NWListener.Service(
            name: UIDevice.current.name,
            type: "_markpush._tcp",
            domain: "local",
            txtRecord: NWTXTRecord(["id": deviceID, "v": "1"])
        )
        // ... accept connections, upgrade to WebSocket, parse messages
    }
    
    func stop() {
        listener?.cancel()
    }
}
```

### Client (CLI side — sends)

```go
// internal/transport/wifi.go

package transport

import (
    "context"
    "fmt"
    "time"
    
    "github.com/gorilla/websocket"
    "markpush/internal/mdns"
    "markpush/internal/protocol"
)

type WiFiTransport struct {
    timeout time.Duration
}

func (t *WiFiTransport) Send(ctx context.Context, msg *protocol.PushMessage) error {
    // 1. Discover device via mDNS
    device, err := mdns.Discover(ctx, t.timeout)
    if err != nil {
        return fmt.Errorf("discover device: %w", err)
    }
    
    // 2. Connect WebSocket
    url := fmt.Sprintf("ws://%s:%d/ws", device.Host, device.Port)
    conn, _, err := websocket.DefaultDialer.DialContext(ctx, url, nil)
    if err != nil {
        return fmt.Errorf("connect to %s: %w", url, err)
    }
    defer conn.Close()
    
    // 3. Send message as JSON
    return conn.WriteJSON(msg)
}
```

---

## 6. Phase 3 — iOS App (Swift/SwiftUI)

### App Entry + TCA Root

```swift
// App/MarkPushApp.swift

import SwiftUI
import ComposableArchitecture
import SwiftData

@main
struct MarkPushApp: App {
    static let store = Store(initialState: AppReducer.State()) {
        AppReducer()
    }
    
    var body: some Scene {
        WindowGroup {
            AppView(store: Self.store)
                .modelContainer(for: [MarkDocument.self, Device.self, Annotation.self])
        }
    }
}
```

### SwiftData Models

```swift
// Models/MarkDocument.swift

import SwiftData
import Foundation

@Model
final class MarkDocument {
    var id: UUID
    var title: String
    var content: String          // raw markdown
    var receivedAt: Date
    var tags: [String]
    var wordCount: Int
    var isRead: Bool
    var isPinned: Bool
    var isArchived: Bool
    var source: String?          // "claude", "cursor", etc.
    var senderName: String?
    
    // Computed
    var readingTimeMinutes: Int {
        max(1, wordCount / 200)
    }
    var excerpt: String {
        // first non-heading, non-empty line
    }
    
    // Relationships
    var annotations: [Annotation]
    
    init(from message: PushMessage) {
        self.id = UUID(uuidString: message.id) ?? UUID()
        self.title = message.title
        self.content = String(data: Data(base64Encoded: message.content)!, encoding: .utf8) ?? ""
        self.receivedAt = message.timestamp
        self.tags = message.tags
        self.wordCount = message.wordCount
        self.isRead = false
        self.isPinned = false
        self.isArchived = false
        self.source = message.source
        self.senderName = message.senderName
        self.annotations = []
    }
}
```

### Reader Feature (TCA)

```swift
// Features/Reader/ReaderFeature.swift

import ComposableArchitecture

@Reducer
struct ReaderFeature {
    @ObservableState
    struct State: Equatable {
        var document: MarkDocument
        var isTOCVisible: Bool = false
        var fontSize: CGFloat = 17
        var theme: ReaderTheme = .system
        var isAnnotating: Bool = false
        var scrollProgress: Double = 0
        var headings: [DocumentHeading] = []
        var annotations: IdentifiedArrayOf<Annotation> = []
        var aiSummary: String? = nil
        var isLoadingAISummary: Bool = false
    }
    
    enum Action {
        case toggleTOC
        case setFontSize(CGFloat)
        case setTheme(ReaderTheme)
        case scrollProgressChanged(Double)
        case headingsExtracted([DocumentHeading])
        case annotationAdded(Annotation)
        case annotationDeleted(UUID)
        case requestAISummary
        case aiSummaryResponse(Result<String, MarkPushError>)
        case shareDocument
        case exportAsPDF
        case copyMarkdown
        case archiveDocument
        case togglePin
    }
    
    @Dependency(\.markPushClient) var client
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .toggleTOC:
                state.isTOCVisible.toggle()
                return .none
                
            case .requestAISummary:
                state.isLoadingAISummary = true
                let content = state.document.content
                return .run { send in
                    await send(.aiSummaryResponse(
                        Result { try await client.summarize(content) }
                    ))
                }
            // ... other cases
            }
        }
    }
}
```

### Reader View

```swift
// Features/Reader/ReaderView.swift

import SwiftUI
import ComposableArchitecture
import MarkdownUI

struct ReaderView: View {
    @Bindable var store: StoreOf<ReaderFeature>
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack(alignment: .trailing) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Document header
                        DocumentHeaderView(document: store.document)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        // Markdown content
                        Markdown(store.document.content)
                            .markdownTheme(readerTheme)
                            .markdownCodeSyntaxHighlighter(.splash(theme: splashTheme))
                            .padding(.horizontal, 20)
                            .padding(.bottom, 60)
                            .textSelection(.enabled)
                    }
                }
                .scrollIndicators(.hidden)
            }
            
            // TOC Drawer (slides in from right)
            if store.isTOCVisible {
                TOCDrawer(
                    headings: store.headings,
                    onSelect: { heading in
                        // scroll to heading
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { readerToolbar }
        .sheet(isPresented: $store.isAnnotating) {
            AnnotationSheet(store: store)
        }
        .animation(.spring(response: 0.3), value: store.isTOCVisible)
    }
    
    private var readerTheme: MarkdownUI.Theme {
        Theme()
            .text { FontSize(store.fontSize) }
            .heading1 { FontWeight(.bold); FontSize(store.fontSize * 1.5) }
            .heading2 { FontWeight(.semibold); FontSize(store.fontSize * 1.3) }
            .code { FontFamilyVariant(.monospaced); FontSize(store.fontSize * 0.9) }
            .codeBlock { 
                BackgroundColor(Color(.systemGray6))
                FontFamilyVariant(.monospaced)
            }
    }
    
    @ToolbarContentBuilder
    private var readerToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                // AI Summary button
                Button { store.send(.requestAISummary) } label: {
                    Image(systemName: "sparkles")
                }
                // TOC toggle
                Button { store.send(.toggleTOC) } label: {
                    Image(systemName: "list.bullet")
                }
                // Share menu
                Menu {
                    Button("Copy Markdown") { store.send(.copyMarkdown) }
                    Button("Export as PDF") { store.send(.exportAsPDF) }
                    ShareLink(item: store.document.content)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
}
```

### Live Feed View (incoming docs)

```swift
// Features/Feed/FeedView.swift

struct FeedView: View {
    @Bindable var store: StoreOf<FeedFeature>
    
    var body: some View {
        NavigationStack {
            Group {
                if store.documents.isEmpty {
                    EmptyFeedView()  // "Push your first doc from terminal"
                } else {
                    List {
                        ForEach(store.documents) { doc in
                            NavigationLink(
                                state: AppReducer.Path.State.reader(ReaderFeature.State(document: doc))
                            ) {
                                DocCard(document: doc)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button("Archive", role: .destructive) {
                                            store.send(.archiveDocument(doc.id))
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button("Pin") {
                                            store.send(.togglePin(doc.id))
                                        }
                                        .tint(.orange)
                                    }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("MarkPush")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ConnectionStatusBadge(isConnected: store.isConnected)
                }
            }
        }
        .task { await store.send(.startReceiving).finish() }
    }
}
```

### Doc Card Component

```swift
// UI/Components/DocCard.swift

struct DocCard: View {
    let document: MarkDocument
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Source badge (claude, cursor, etc.)
                if let source = document.source {
                    SourceBadge(source: source)
                }
                Spacer()
                Text(document.receivedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(document.title)
                .font(.headline)
                .lineLimit(2)
            
            Text(document.excerpt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            HStack(spacing: 12) {
                // Word count + reading time
                Label("\(document.readingTimeMinutes) min read", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Tags
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(document.tags, id: \.self) { tag in
                            TagPill(tag: tag)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .leading) {
            if !document.isRead {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
                    .offset(x: -12)
            }
        }
    }
}
```

### iOS Swift Package Dependencies

Add to `Package.swift` or via Xcode SPM:

```swift
dependencies: [
    // TCA — state management
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.15.0"),
    
    // Markdown rendering — full GFM support
    .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
    
    // Syntax highlighting — native Swift, no JS
    .package(url: "https://github.com/JohnSundell/Splash", from: "0.16.0"),
    
    // Supabase client
    .package(url: "https://github.com/supabase/supabase-swift", from: "2.5.0"),
    
    // QR code scanner (for pairing)
    .package(url: "https://github.com/twostraws/CodeScanner", from: "2.5.0"),
    
    // Keychain wrapper
    .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
    
    // Markdown-to-attributed string for text selection
    .package(url: "https://github.com/apple/swift-markdown", from: "0.5.0"),
]
```

---

## 7. Phase 4 — Cloud Relay

### Supabase Schema

```sql
-- supabase/migrations/001_init.sql

-- Enable realtime on pushes table
create table public.pushes (
    id          uuid primary key default gen_random_uuid(),
    created_at  timestamptz default now(),
    
    -- Routing
    sender_id   text not null,
    receiver_id text not null,         -- iOS device UUID
    
    -- Content (always encrypted)
    payload     text not null,         -- base64 AES-256-GCM encrypted PushMessage JSON
    
    -- Delivery status
    delivered   boolean default false,
    delivered_at timestamptz,
    
    -- TTL: auto-delete after 7 days (set up cron or use pg_cron)
    expires_at  timestamptz default (now() + interval '7 days')
);

-- Row-level security: devices can only read pushes addressed to them
alter table public.pushes enable row level security;

create policy "receivers can read their own pushes"
    on public.pushes for select
    using (receiver_id = current_setting('app.device_id', true));

-- Index for efficient polling
create index idx_pushes_receiver on public.pushes(receiver_id, delivered, created_at);

-- Enable Realtime for this table
alter publication supabase_realtime add table public.pushes;
```

### Cloud Transport (Go CLI side)

```go
// internal/transport/cloud.go

package transport

import (
    "bytes"
    "context"
    "encoding/json"
    "fmt"
    "net/http"
    
    "markpush/internal/config"
    "markpush/internal/protocol"
)

type CloudTransport struct {
    supabaseURL string
    supabaseKey string
    receiverID  string
}

func (t *CloudTransport) Send(ctx context.Context, msg *protocol.PushMessage) error {
    payload, err := json.Marshal(msg)
    if err != nil {
        return fmt.Errorf("marshal message: %w", err)
    }
    
    body := map[string]interface{}{
        "sender_id":   msg.SenderID,
        "receiver_id": t.receiverID,
        "payload":     payload, // already encrypted in msg.Content
    }
    
    b, _ := json.Marshal(body)
    req, err := http.NewRequestWithContext(ctx, "POST", 
        t.supabaseURL+"/rest/v1/pushes", bytes.NewReader(b))
    req.Header.Set("apikey", t.supabaseKey)
    req.Header.Set("Authorization", "Bearer "+t.supabaseKey)
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("Prefer", "return=minimal")
    
    resp, err := http.DefaultClient.Do(req)
    if err != nil {
        return fmt.Errorf("send to cloud: %w", err)
    }
    defer resp.Body.Close()
    
    if resp.StatusCode >= 400 {
        return fmt.Errorf("cloud relay error: HTTP %d", resp.StatusCode)
    }
    return nil
}
```

### Cloud Receiver (iOS side)

```swift
// Transport/CloudReceiver.swift

import Supabase
import Foundation

actor CloudReceiver {
    private let client: SupabaseClient
    private let deviceID: String
    private let decryptionKey: Data
    
    var messages: AsyncStream<PushMessage> {
        AsyncStream { continuation in
            Task {
                // Subscribe to realtime changes on pushes table
                // where receiver_id = self.deviceID
                let channel = client.realtimeV2.channel("pushes:\(deviceID)")
                let changes = await channel.postgresChange(
                    InsertAction.self,
                    table: "pushes",
                    filter: .eq("receiver_id", value: deviceID)
                )
                
                await channel.subscribe()
                
                for await change in changes {
                    guard let payload = change.record["payload"]?.stringValue,
                          let message = try? decryptAndDecode(payload) else { continue }
                    
                    // Mark as delivered
                    try? await client.from("pushes")
                        .update(["delivered": true, "delivered_at": Date.now])
                        .eq("id", value: change.record["id"]!.stringValue!)
                        .execute()
                    
                    continuation.yield(message)
                }
            }
        }
    }
    
    private func decryptAndDecode(_ payload: String) throws -> PushMessage {
        // AES-256-GCM decrypt using shared key, then JSON decode
    }
}
```

### Auto-Transport Selection (CLI)

```go
// internal/transport/transport.go

// Select automatically picks the best transport.
// Priority: WiFi (if device found within 2s) → Cloud (fallback)
func Select(ctx context.Context, cfg *config.Config) (Transport, error) {
    if cfg.ForceWiFi {
        return &WiFiTransport{timeout: 5 * time.Second}, nil
    }
    if cfg.ForceCloud {
        return NewCloudTransport(cfg), nil
    }
    
    // Race: try mDNS discovery for 2 seconds
    discoverCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
    defer cancel()
    
    device, err := mdns.Discover(discoverCtx, 2*time.Second)
    if err == nil && device != nil {
        return &WiFiTransport{device: device}, nil
    }
    
    // Fallback to cloud
    return NewCloudTransport(cfg), nil
}
```

---

## 8. Phase 5 — Power Features

### AI Summary (Anthropic API)

```swift
// Clients/MarkPushClientLive.swift

func summarize(_ content: String) async throws -> String {
    let request = AnthropicRequest(
        model: "claude-haiku-4-5",    // fast + cheap for summaries
        max_tokens: 300,
        system: """
            You are a document summarizer. Produce a concise 3-5 sentence summary 
            of the key points. Focus on what someone needs to know to decide 
            whether to read the full document. Use plain prose, no bullet points.
            """,
        messages: [
            .init(role: "user", content: "Summarize this document:\n\n\(content.prefix(8000))")
        ]
    )
    // Call Anthropic API, return text content
}
```

### Watch Mode (CLI)

```go
// cmd/watch.go — `markpush watch ./docs/`

// Uses fsnotify to watch a directory.
// Debounces writes (300ms), then pushes changed .md files automatically.
// Shows a live TUI with list of pushed files and timestamps.
```

### Highlights + Annotations (iOS)

```swift
// Models/Annotation.swift

@Model
final class Annotation {
    var id: UUID
    var documentID: UUID
    var selectedText: String
    var note: String?
    var color: AnnotationColor
    var characterRange: NSRange  // stored as location + length
    var createdAt: Date
    
    enum AnnotationColor: String, Codable {
        case yellow, blue, green, pink
    }
}
```

### Apple Watch Complication

```swift
// WatchExtension/ComplicationView.swift
// Shows: latest doc title + word count + time received
// Tap opens last received doc in phone app via WatchConnectivity
```

### Shortcuts / Siri Integration

```swift
// Add AppIntents for:
// - "Show latest push" 
// - "Push file [name] to phone"  (via Shortcuts)
// - "Summarize last push"
```

---

## 9. Phase 6 — Open Source Packaging

### Homebrew Formula

```ruby
# Formula/markpush.rb (in homebrew-markpush tap)
class Markpush < Formula
  desc "Push AI-generated markdown from terminal to iPhone"
  homepage "https://github.com/yourusername/markpush"
  url "https://github.com/yourusername/markpush/releases/download/v1.0.0/markpush_darwin_arm64.tar.gz"
  sha256 "..."
  license "MIT"
  
  def install
    bin.install "markpush"
  end
  
  test do
    system "#{bin}/markpush", "--version"
  end
end
```

### One-line Install Script

```bash
# scripts/install.sh
#!/bin/bash
# curl -fsSL https://markpush.dev/install.sh | bash

REPO="yourusername/markpush"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Download latest release binary
# Add to PATH
# Print next steps: markpush pair
```

### GoReleaser Config

```yaml
# .goreleaser.yml
project_name: markpush
builds:
  - id: markpush
    main: ./cli
    binary: markpush
    goos: [darwin, linux, windows]
    goarch: [amd64, arm64]
    ldflags:
      - -s -w
      - -X main.version={{.Version}}

brews:
  - tap:
      owner: yourusername
      name: homebrew-markpush
    description: "Push AI-generated markdown from terminal to iPhone"

archives:
  - format: tar.gz
    format_overrides:
      - goos: windows
        format: zip

checksum:
  name_template: "checksums.txt"

release:
  github:
    owner: yourusername
    name: markpush
```

### GitHub Actions — CI

```yaml
# .github/workflows/ci-ios.yml
name: iOS CI
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app
      - name: Build
        run: xcodebuild build-for-testing -scheme MarkPush -destination 'platform=iOS Simulator,name=iPhone 16'
      - name: Test
        run: xcodebuild test -scheme MarkPush -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## 10. iOS UI/UX Design Spec

### Typography System

```swift
// UI/Theme.swift

extension Font {
    // Headings
    static let readerTitle = Font.system(.largeTitle, design: .serif, weight: .bold)
    static let readerH1 = Font.system(.title, design: .serif, weight: .bold)
    static let readerH2 = Font.system(.title2, design: .serif, weight: .semibold)
    static let readerH3 = Font.system(.title3, design: .default, weight: .semibold)
    
    // Body — using `.default` (SF Pro) for technical content, `.serif` optional
    static let readerBody = Font.system(.body, design: .default)
    static let readerBodySerif = Font.system(.body, design: .serif)  // reader toggle
    
    // Code — always monospaced
    static let readerCode = Font.system(.callout, design: .monospaced)
    
    // UI chrome
    static let cardTitle = Font.system(.headline, weight: .semibold)
    static let cardMeta = Font.system(.caption, weight: .regular)
}
```

### Color Semantic System

```swift
extension Color {
    // Surfaces
    static let readerBackground = Color("ReaderBackground")  // warm off-white / dark bg
    static let codeBackground = Color("CodeBackground")
    
    // Source badges
    static let sourceClaude = Color(.systemPurple)
    static let sourceCursor = Color(.systemBlue)
    static let sourceManual = Color(.systemGray)
    
    // Annotation colors
    static let annotationYellow = Color(.systemYellow).opacity(0.3)
    static let annotationBlue = Color(.systemBlue).opacity(0.25)
    static let annotationGreen = Color(.systemGreen).opacity(0.25)
    static let annotationPink = Color(.systemPink).opacity(0.25)
    
    // Status
    static let connected = Color(.systemGreen)
    static let disconnected = Color(.systemRed)
    static let syncing = Color(.systemOrange)
}
```

### Animation Guidelines

```swift
// Standard spring for card transitions
static let cardSpring = Animation.spring(response: 0.35, dampingFraction: 0.75)

// TOC drawer slide
static let drawerSlide = Animation.spring(response: 0.3, dampingFraction: 0.85)

// AI summary appearance
static let summaryReveal = Animation.easeOut(duration: 0.4)

// Connection badge pulse (when syncing)
// Use .repeatForever(autoreverses: true) with opacity animation
```

### Reader UX Rules

1. **No chrome in reading mode** — toolbar fades out after 3 seconds, tap to restore
2. **Dynamic Type support** — all text scales with system font size
3. **Swipe from left edge** → go back to library (NavigationStack default)
4. **Two-finger swipe up** → jump to top
5. **Long press on code block** → copy to clipboard with haptic feedback
6. **Tap on external link** → SFSafariViewController (never leave the app)
7. **Tables scroll horizontally** if wider than screen
8. **Reading progress bar** — thin bar at top of screen (0.5pt height, matches accent color)

### Pairing Screen UX

```swift
// Features/Pairing/PairingView.swift

// Step 1: "Open MarkPush on your Mac or Linux terminal"
//         "Run: markpush pair"
// Step 2: "Scan the QR code that appears in your terminal"
//         [CodeScanner view — full screen camera]
// Step 3: Success animation + device name confirmation
//         "Connected to [hostname]!"

// Important: scan happens inline, NOT in a separate modal
// Use CodeScanner by twostraws — it handles permissions gracefully
```

---

## 11. API Contracts

### WebSocket Message Protocol

All messages are JSON. Encryption wraps the `content` field only.

```typescript
// Shared protocol types (documented here, implemented in Go + Swift)

interface BaseMessage {
  version: "1";
  type: "push" | "pair_init" | "pair_ack" | "ping" | "pong" | "ack" | "error";
  id: string;          // UUID v4
  timestamp: string;   // ISO 8601
}

interface PushMessage extends BaseMessage {
  type: "push";
  title: string;
  tags: string[];
  source?: "claude" | "cursor" | "windsurf" | "manual" | string;
  word_count: number;
  content: string;     // base64-encoded markdown (optionally AES-256-GCM encrypted)
  encrypted: boolean;
  sender_id: string;
  sender_name: string;
}

interface AckMessage extends BaseMessage {
  type: "ack";
  ref_id: string;      // ID of the push message being acknowledged
  status: "received" | "error";
  error?: string;
}

interface PairInitMessage extends BaseMessage {
  type: "pair_init";
  secret: string;      // base64 random 32 bytes
  sender_id: string;
  sender_name: string;
  sender_host: string;
  pairing_port: number;
}
```

### Pairing Protocol Flow

```
CLI                                 iOS App
 │                                     │
 │── (1) markpush pair ─────────────── │
 │    Generates secret                 │
 │    Shows QR in terminal             │
 │    Starts HTTP server on :PORT      │
 │                                     │
 │                          (2) User scans QR
 │                              iOS decodes payload:
 │                              { secret, host, port, sender_id, sender_name }
 │                                     │
 │◄── (3) POST /pair ─────────────────-│
 │    { device_id, device_name,        │
 │      public_ack }                   │
 │                                     │
 │── (4) 200 OK ──────────────────────►│
 │    { confirmed: true }              │
 │                                     │
 │  Both sides derive shared key:      │
 │  key = PBKDF2(secret, device_id, 100000, SHA-256)
 │                                     │
 │  CLI saves: devices.toml           │
 │  iOS saves: Keychain               │
```

---

## 12. Testing Strategy

### Go CLI Tests

```go
// cli/internal/transport/wifi_test.go

func TestWiFiTransport_Send(t *testing.T) {
    // Spin up a test WebSocket server
    // Send a test message
    // Assert message received and decoded correctly
    // Assert encryption round-trips
}

func TestMDNS_Discover(t *testing.T) {
    // Requires network, skip in CI: t.Skip("integration")
    // Or mock the mDNS resolver
}

func TestEncryptDecrypt(t *testing.T) {
    key := make([]byte, 32)
    rand.Read(key)
    
    original := []byte("# Hello World\nThis is markdown.")
    encrypted, err := crypto.Encrypt(key, original)
    require.NoError(t, err)
    
    decrypted, err := crypto.Decrypt(key, encrypted)
    require.NoError(t, err)
    require.Equal(t, original, decrypted)
}
```

### Swift Tests (TCA)

```swift
// MarkPushTests/ReaderFeatureTests.swift

@MainActor
final class ReaderFeatureTests: XCTestCase {
    func testToggleTOC() async {
        let store = TestStore(initialState: ReaderFeature.State(document: .mock)) {
            ReaderFeature()
        }
        
        await store.send(.toggleTOC) { state in
            state.isTOCVisible = true
        }
        await store.send(.toggleTOC) { state in
            state.isTOCVisible = false
        }
    }
    
    func testAISummaryRequest() async {
        let store = TestStore(initialState: ReaderFeature.State(document: .mock)) {
            ReaderFeature()
        } withDependencies: {
            $0.markPushClient.summarize = { _ in "This is a test summary." }
        }
        
        await store.send(.requestAISummary) { state in
            state.isLoadingAISummary = true
        }
        await store.receive(.aiSummaryResponse(.success("This is a test summary."))) { state in
            state.isLoadingAISummary = false
            state.aiSummary = "This is a test summary."
        }
    }
}
```

### UI Snapshot Tests

Use `swift-snapshot-testing` by Point-Free for all views:

```swift
func testDocCard_Unread() {
    let view = DocCard(document: .mock(isRead: false))
    assertSnapshot(of: view, as: .image(layout: .fixed(width: 390)))
}

func testReaderView_DarkMode() {
    let store = TestStore(...)
    let view = ReaderView(store: store)
        .environment(\.colorScheme, .dark)
    assertSnapshot(of: view, as: .image(layout: .device(.iPhone15Pro)))
}
```

---

## 13. Claude Code Prompts — Session Starters

Use these to kick off each coding session in Claude Code:

### Session 1: Project Scaffolding

```
Read CLAUDE.md first, then:

Initialize the Go module for the CLI tool:
1. Create cli/go.mod with module name "github.com/yourusername/markpush"
2. Add all dependencies listed in MARKPUSH_IMPLEMENTATION_PLAN.md Phase 1
3. Create the cobra command structure: root, push, pair, watch, history, config
4. Implement internal/protocol/message.go with all message types
5. Add a Makefile with build, test, lint targets
6. Create .gitignore for Go and Swift artifacts

Run `go build ./...` to verify it compiles. Fix any errors before stopping.
```

### Session 2: CLI Core Logic

```
Read CLAUDE.md first, then:

Implement the push command fully:
1. internal/crypto/aes.go — AES-256-GCM encrypt/decrypt + PBKDF2 key derivation
2. internal/config/config.go — Viper config, reads ~/.config/markpush/config.toml
3. cmd/push.go — reads file or stdin, extracts title from first H1, counts words,
   builds PushMessage, encrypts content, calls transport
4. Write table-driven tests for crypto functions
5. Test with: echo "# Hello\nWorld" | go run ./cli push --stdin --dry-run

All errors must be wrapped with fmt.Errorf("context: %w", err).
Use lipgloss for terminal output styling.
```

### Session 3: WiFi Transport

```
Read CLAUDE.md first. We're implementing WiFi transport.

1. internal/mdns/discover.go — use hashicorp/mdns to query _markpush._tcp.local.
   Return the first device matching our paired device ID from TXT records.
2. internal/transport/wifi.go — dial WebSocket to discovered device, send JSON message,
   wait for ACK with 10s timeout, close cleanly.
3. internal/transport/transport.go — Select() function: race mDNS for 2s, fallback to cloud.
4. Write integration test (skipped in CI with t.Skip) that sends to a local test server.

Use gorilla/websocket. Handle connection refused gracefully with user-friendly error message.
```

### Session 4: iOS Project Setup

```
Read CLAUDE.md first.

Set up the iOS Xcode project:
1. Create MarkPush.xcodeproj with SwiftUI lifecycle
2. Add all SPM packages listed in Phase 3 of the plan
3. Create folder structure: App/, Features/, Models/, Clients/, Transport/, UI/
4. Create SwiftData models: MarkDocument, Device, Annotation (exact fields from plan)
5. Set up TCA AppReducer with NavigationStack path routing
6. Configure SwiftLint with .swiftlint.yml (standard rules + custom: no_force_cast, no_print)
7. Enable strict concurrency checking in Build Settings

Ensure the app builds and runs on iPhone 16 simulator with an empty state before stopping.
```

### Session 5: Reader View

```
Read CLAUDE.md first. We're building the core Reader experience — this is the most important UI.

Build ReaderFeature.swift and ReaderView.swift:
1. Full TCA reducer with all actions from the plan
2. ReaderView with:
   - MarkdownUI rendering with custom theme (serif option, adjustable font size 14-24pt)
   - Syntax highlighting via Splash
   - TOC drawer (AnimatedSlide from right, blur background)
   - Reading progress bar (thin, top of screen)
   - Toolbar that fades after 3s, restored on tap
3. DocumentHeaderView showing title, sender, timestamp, tags, reading time
4. TOCDrawer component — extracts H1/H2/H3, scrolls on tap
5. Write TCA unit tests for all reducer actions

Use system haptics (UIImpactFeedbackGenerator) for long-press code copy.
Match iOS reading app conventions (think: Instapaper, Apple Books feel).
```

### Session 6: Pairing Flow

```
Read CLAUDE.md first.

Implement the full pairing flow end-to-end:

CLI side:
1. cmd/pair.go — generate 32-byte secret, encode as QR in terminal (go-qrcode + lipgloss box),
   start ephemeral HTTP server, wait for iOS POST /pair, save to config

iOS side:
1. PairingFeature.swift + PairingView.swift using TCA
2. Step-by-step UX: instructions → camera (CodeScanner) → success animation
3. On successful scan: POST to CLI's /pair endpoint, derive shared key, save to Keychain
4. PairingView should handle: camera permission denied, QR parse error, network timeout

Test by running `go run ./cli pair` in terminal and scanning the QR with the simulator.
The pairing secret must never be logged or stored in plaintext.
```

### Session 7: Cloud Relay (Supabase)

```
Read CLAUDE.md first.

Implement cloud relay:
1. Create supabase/migrations/001_init.sql (exact schema from plan)
2. internal/transport/cloud.go — POST to Supabase REST API with encrypted payload
3. iOS CloudReceiver.swift — subscribe to Supabase Realtime, decrypt on receipt,
   mark as delivered
4. Update transport.Select() to use cloud when WiFi unavailable
5. Add SUPABASE_URL and SUPABASE_ANON_KEY to config (CLI) and Info.plist references (iOS)

The device_id used for RLS must come from the shared pairing secret derivation,
not from a user-controlled value.
```

### Session 8: AI Summary + Power Features

```
Read CLAUDE.md first.

Add AI summary feature:
1. MarkPushClientLive.swift — implement summarize() using Anthropic API
   (model: claude-haiku-4-5, max 300 tokens, system prompt from plan)
2. ReaderView AI summary sheet: loading state with shimmer, result in expandable card
3. CLI watch mode: cmd/watch.go using fsnotify, 300ms debounce, push on .md change
4. Share sheet: export as PDF (WKWebView markdown→HTML→PDF), Notion URL scheme,
   system share sheet for raw markdown
5. Annotation model + highlight UI using TextSelection + custom overlay

The API key for Anthropic must be stored in iOS Keychain, configured in Settings screen.
```

---

## Quick Reference: Key Commands

```bash
# Development
markpush push README.md              # push a file
markpush push --stdin < output.md    # pipe from stdin
markpush push --dry-run notes.md     # preview without sending
markpush pair                        # pair with iOS app
markpush watch ./docs/               # watch directory
markpush history                     # list recent pushes
markpush config set cloud.enabled true

# Pipe from AI agents
claude "design the auth system" | markpush push --title "Auth Design" --tag backend
aider --message "..." | markpush push
cat agent_output.md | markpush push --source cursor

# Build
make build       # compile CLI binary
make test        # run all Go tests
make lint        # golangci-lint

# iOS
open ios/MarkPush.xcodeproj
xcodebuild test -scheme MarkPush -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## Open Source Checklist

- [ ] MIT LICENSE file
- [ ] CONTRIBUTING.md with PR guidelines, code style, commit format (Conventional Commits)
- [ ] SECURITY.md — responsible disclosure policy
- [ ] CODE_OF_CONDUCT.md — Contributor Covenant
- [ ] Issue templates: bug report, feature request, question
- [ ] PR template with checklist
- [ ] GitHub Actions: CI for Go + iOS, GoReleaser for releases
- [ ] README with: demo GIF, one-line install, quick start, screenshot of iOS app
- [ ] Self-hosting guide for cloud relay
- [ ] Swift Package Index listing
- [ ] Homebrew tap with formula

---

*Built with Claude Code. Designed for developers who want to read their AI's work beautifully.*
