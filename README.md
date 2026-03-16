# MarkPush

> Push AI-generated markdown from your terminal to a beautiful iOS reader. One command. Instant delivery.

*"Pocket for your AI outputs."*

---

## What is MarkPush?

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

MarkPush takes markdown files — Claude outputs, AI-generated docs, notes — and pushes them to your iPhone for comfortable reading. Works over local WiFi (zero-config, instant) or cloud relay (when you're away from home).

## Features

- **One command** — `markpush push README.md` and it's on your phone
- **Zero config** — WiFi transport auto-discovers your phone via Bonjour
- **End-to-end encrypted** — AES-256-GCM, keys never leave your devices
- **Beautiful reader** — Native iOS app with syntax highlighting, table of contents, annotations
- **Pipe-friendly** — `cat output.md | markpush push --stdin`
- **Watch mode** — `markpush watch ./docs/` pushes on every save
- **Cloud relay** — Works remotely via Supabase Realtime (self-hostable)
- **AI summaries** — Quick document summaries powered by Claude Haiku

## Quick Start

### Install the CLI

```bash
# macOS (Homebrew)
brew install rahilsinghi/tap/markpush

# Or from source
go install github.com/rahilsinghi/markpush/cli@latest
```

### Install the iOS App

Download from the [App Store](#) (coming soon) or build from source.

### Pair Your Devices

```bash
# On your computer
markpush pair

# Scan the QR code with the MarkPush iOS app
# Done! Devices are now paired with end-to-end encryption
```

### Push Your First Document

```bash
markpush push README.md
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| CLI | Go (cobra, viper, lipgloss) |
| Local transport | WebSocket + mDNS (Bonjour) |
| Cloud relay | Supabase Realtime |
| iOS app | Swift + SwiftUI + TCA |
| Markdown rendering | swift-markdown-ui |
| Encryption | AES-256-GCM |
| Persistence | SwiftData + iCloud |

## Project Structure

```
markpush/
├── cli/          ← Go CLI tool
├── ios/          ← SwiftUI iOS app
├── relay/        ← Self-hostable cloud relay (Supabase)
├── docs/         ← Architecture & API docs
└── scripts/      ← Install & release scripts
```

## Development

### Prerequisites

- Go 1.22+
- Xcode 16+ (for iOS)
- Supabase CLI (optional, for cloud relay)

### Build

```bash
# CLI
make build

# Run tests
make test

# Lint
make lint
```

### iOS

Open `ios/MarkPush.xcodeproj` in Xcode and run.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT — see [LICENSE](LICENSE) for details.
