# Architecture

## Overview

MarkPush has two main components that communicate over a shared protocol:

```
┌──────────────┐         ┌──────────────┐
│   CLI (Go)   │ ──────► │  iOS (Swift) │
│  markpush    │  push   │  MarkPush    │
└──────────────┘         └──────────────┘
       │                        │
       └────────┬───────────────┘
                │
         ┌──────┴──────┐
         │  Transport  │
         │  Layer      │
         └─────────────┘
              │    │
         WiFi ▼    ▼ Cloud
       (WebSocket) (Supabase
        + mDNS)    Realtime)
```

## Transport Layer

### WiFi (Local)
- **Discovery:** mDNS/Bonjour — iOS app advertises `_markpush._tcp` service
- **Connection:** WebSocket over local network
- **Latency:** <50ms on typical home networks
- **Availability:** Same network required

### Cloud (Remote)
- **Provider:** Supabase Realtime (PostgreSQL-backed)
- **Connection:** iOS subscribes to realtime changes on `pushes` table filtered by device ID
- **Latency:** 200-500ms typical
- **Availability:** Internet required, self-hostable

### Auto-Selection
CLI tries WiFi first (2s timeout for mDNS discovery), falls back to cloud.
User can force either with `--wifi` or `--cloud` flags.

## Security

### Pairing
1. CLI generates 32-byte random secret
2. Secret encoded as QR code shown in terminal
3. iOS scans QR, both derive shared key via PBKDF2(secret, device_id, 100000, SHA-256)
4. Key stored in Keychain (iOS) and `~/.config/markpush/devices.toml` (CLI)

### Encryption
- AES-256-GCM for all content
- Random nonce per message
- Only the `content` field is encrypted — routing metadata stays in plaintext
- Cloud relay sees only encrypted blobs

## Data Flow

```
1. User runs: markpush push doc.md
2. CLI reads file, extracts title from first H1, counts words
3. CLI builds PushMessage JSON
4. CLI encrypts content field with shared key
5. CLI discovers device (mDNS) or sends to cloud relay
6. iOS receives message, decrypts, creates SwiftData model
7. iOS shows notification + updates feed
```

## iOS Architecture

- **State Management:** TCA (The Composable Architecture)
- **Persistence:** SwiftData with iCloud sync
- **Pattern:** Feature → Action → State → Reducer → View
- **Dependencies:** Injectable via TCA's `@Dependency` system
