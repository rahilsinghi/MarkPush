# MarkPush — System Architecture

## Full System Overview

```
                    ┌─────────────────────────────────────────┐
                    │           Entry Points                   │
                    │                                         │
                    │  ┌──────────┐     ┌──────────────────┐  │
                    │  │ CLI (Go) │     │ MCP Server (TS)  │  │
                    │  │ markpush │     │ @markpush/mcp    │  │
                    │  │ push     │     │ push_markdown    │  │
                    │  │ pair     │     │ push_template    │  │
                    │  │ watch    │     │ pair_device      │  │
                    │  └────┬─────┘     └───────┬──────────┘  │
                    │       │                   │              │
                    └───────┼───────────────────┼──────────────┘
                            │                   │
                    ┌───────┴───────────────────┴──────────────┐
                    │          Shared Layer                     │
                    │                                          │
                    │  ~/.config/markpush/                      │
                    │  ├── config.toml    (device ID, prefs)    │
                    │  └── devices.toml   (paired keys)         │
                    │                                          │
                    │  Protocol: PushMessage JSON v1            │
                    │  Crypto:   AES-256-GCM + PBKDF2          │
                    └───────────────────┬──────────────────────┘
                                        │
                               ┌────────┴────────┐
                               │                 │
                    ┌──────────▼───┐    ┌────────▼──────────┐
                    │ WiFi         │    │ Cloud Relay        │
                    │ Transport    │    │ Transport          │
                    │              │    │                    │
                    │ mDNS/Bonjour │    │ Supabase Realtime  │
                    │ WebSocket    │    │ REST API + RLS     │
                    │              │    │ E2E Encrypted      │
                    │ Same network │    │ Any network        │
                    │ <50ms        │    │ 200-500ms          │
                    └──────┬───────┘    └────────┬──────────┘
                           │                     │
                           └──────────┬──────────┘
                                      │
                    ┌─────────────────▼────────────────────────┐
                    │          iOS App (SwiftUI + TCA)          │
                    │                                          │
                    │  ┌──────────────────────────────────┐    │
                    │  │ Transport Layer                   │    │
                    │  │ WiFiReceiver ←→ CloudReceiver     │    │
                    │  └──────────────┬───────────────────┘    │
                    │                 │                         │
                    │  ┌──────────────▼───────────────────┐    │
                    │  │ Decrypt + Store                   │    │
                    │  │ CryptoUtils → SwiftData           │    │
                    │  └──────────────┬───────────────────┘    │
                    │                 │                         │
                    │  ┌──────────────▼───────────────────┐    │
                    │  │ Features (TCA)                    │    │
                    │  │ Feed │ Reader │ Library │ Settings│    │
                    │  └──────────────────────────────────┘    │
                    └──────────────────────────────────────────┘
```

## Protocol Message Flow

### Push (CLI or MCP → iOS)

```
Sender                              Receiver
  │                                    │
  │  1. PushMessage (JSON)             │
  │  ┌─────────────────────────┐       │
  │  │ version: "1"            │       │
  │  │ type: "push"            │       │
  │  │ id: UUID                │       │
  │  │ title: "Doc Title"     │       │
  │  │ content: base64(AES())  │       │
  │  │ encrypted: true         │       │
  │  │ sender_id: "cli-uuid"   │       │
  │  │ word_count: 234         │       │
  │  └─────────────────────────┘       │
  │──────────────────────────────────►│
  │                                    │
  │  2. AckMessage (JSON)              │
  │  ┌─────────────────────────┐       │
  │  │ type: "ack"             │       │
  │  │ ref_id: (push msg id)   │       │
  │  │ status: "received"      │       │
  │  └─────────────────────────┘       │
  │◄──────────────────────────────────│
```

### Pairing (CLI/MCP ↔ iOS)

```
CLI / MCP Server                    iOS App
  │                                    │
  │  1. Generate 32-byte secret        │
  │  2. Show QR code in terminal       │
  │     (contains JSON payload)        │
  │                                    │
  │     QR Payload:                    │
  │     ┌─────────────────────┐        │
  │     │ v: "1"              │        │
  │     │ s: base64(secret)   │        │
  │     │ h: "192.168.1.42"   │        │
  │     │ p: 54321            │        │
  │     │ id: "sender-uuid"   │        │
  │     │ name: "MacBook"     │        │
  │     └─────────────────────┘        │
  │                                    │
  │  3. Start HTTP server on :PORT     │
  │                                    │
  │              4. User scans QR ─────│
  │                                    │
  │◄─── 5. POST /pair ───────────────│
  │     { device_id, device_name }     │
  │                                    │
  │──── 6. 200 { confirmed: true } ──►│
  │                                    │
  │  7. Both derive key independently: │
  │     key = PBKDF2(                  │
  │       password: secret,            │
  │       salt: ios_device_id,         │
  │       iterations: 100000,          │
  │       hash: SHA-256,               │
  │       length: 32                   │
  │     )                              │
  │                                    │
  │  8. CLI: saves to devices.toml     │
  │     iOS: saves to Keychain         │
```

## Encryption Format

```
 Plaintext (markdown bytes)
         │
         ▼
 ┌───────────────────┐
 │ AES-256-GCM       │
 │ key: 32 bytes     │
 │ nonce: random     │
 │       12 bytes    │
 └───────┬───────────┘
         │
         ▼
 ┌───────────────────────────────────────────┐
 │ nonce (12B) │ ciphertext (N B) │ tag (16B)│
 └───────────────────────────────────────────┘
         │
         ▼
 base64 encode → content field in PushMessage
```

All three clients (Go CLI, TypeScript MCP, Swift iOS) produce and consume
this exact same format.

## Transport Selection

```
         ┌───────────────────┐
         │ Select Transport  │
         │ mode = ?          │
         └────────┬──────────┘
                  │
        ┌─────────┼──────────┐
        │         │          │
   ┌────▼───┐ ┌──▼────┐ ┌───▼────┐
   │ --wifi │ │ auto  │ │--cloud │
   └────┬───┘ └──┬────┘ └───┬────┘
        │        │           │
        │   ┌────▼────┐      │
        │   │ mDNS    │      │
        │   │ scan    │      │
        │   │ (2 sec) │      │
        │   └────┬────┘      │
        │   found? │ timeout  │
        │   ┌─────┼──────┐   │
        │   │     │      │   │
   ┌────▼───▼─┐   │  ┌───▼───▼──┐
   │ WiFi     │   │  │ Cloud    │
   │ Sender   │   │  │ Sender   │
   │ ws://    │   │  │ Supabase │
   └──────────┘   │  └──────────┘
                  │
            ┌─────▼──────┐
            │ Error:     │
            │ no device, │
            │ no cloud   │
            └────────────┘
```

## iOS App Architecture (TCA)

```
┌───────────────────────────────────────────────────┐
│ AppFeature (root)                                  │
│                                                    │
│  ┌──────────────────────────────────────────┐     │
│  │ AuthFeature (gates entire app)            │     │
│  │ State: step, email, isLoading, error      │     │
│  │ Steps: checking → landing → magicLinkSent │     │
│  │        → authenticated                    │     │
│  │ Deep link: markpush://auth/callback       │     │
│  └──────────────────┬───────────────────────┘     │
│                     │ authenticated?               │
│                     ▼                              │
│  ┌────────┐  ┌─────────┐  ┌──────────┐           │
│  │ Feed   │  │ Library │  │ Settings │           │
│  │ Tab    │  │ Tab     │  │ Tab      │           │
│  └───┬────┘  └────┬────┘  └────┬─────┘           │
│      │            │            │                   │
│  ┌───▼─────────┐  │     ┌─────▼──────────┐       │
│  │ FeedFeature │  │     │SettingsFeature │       │
│  │ State:      │  │     │ State:         │       │
│  │  documents  │  │     │  fontSize      │       │
│  │  isConnected│  │     │  hasPaired     │       │
│  │ Actions:    │  │     │  userEmail     │       │
│  │  start      │  │     │ Actions:       │       │
│  │  received   │  │     │  showPairing   │       │
│  │  pin/archive│  │     │  signOut       │       │
│  └───┬─────────┘  │     └────────────────┘       │
│      │            │                               │
│  ┌───▼─────────┐  │  ┌──────────────────┐        │
│  │ReaderFeature│  │  │ PairingFeature   │        │
│  │ State:      │  │  │ State:           │        │
│  │  content    │  │  │  step            │        │
│  │  fontSize   │  │  │  deviceName      │        │
│  │  isTOC      │  │  │ Actions:         │        │
│  │ Actions:    │  │  │  scan            │        │
│  │  toggleTOC  │  │  │  qrCodeScanned   │        │
│  │  setFont    │  │  │  completed       │        │
│  └─────────────┘  │  └──────────────────┘        │
│                   │                               │
│            ┌──────▼──────────┐                    │
│            │ LibraryFeature  │                    │
│            │ State:          │                    │
│            │  searchQuery    │                    │
│            │  filter         │                    │
│            │  sortOrder      │                    │
│            └─────────────────┘                    │
└───────────────────────────────────────────────────┘

Dependencies (injectable):
  AuthClient     → signInWithOTP, handleDeepLink, restoreSession, signOut
  MarkPushClient → startReceiving, decryptContent, completePairing
```

## Cloud Relay (Supabase)

```
┌────────────────────────────────────────────────────┐
│ Supabase                                            │
│                                                     │
│  ┌────────────────────────────────────────────┐     │
│  │ Table: public.pushes                       │     │
│  │                                            │     │
│  │ id          uuid PK                        │     │
│  │ created_at  timestamptz                    │     │
│  │ sender_id   text          ── CLI device    │     │
│  │ receiver_id text          ── iOS device    │     │
│  │ payload     text          ── AES encrypted │     │
│  │ delivered   boolean                        │     │
│  │ delivered_at timestamptz                   │     │
│  │ expires_at  timestamptz   ── now() + 7d    │     │
│  │                                            │     │
│  │ RLS: receiver can only read own pushes     │     │
│  │ Index: (receiver_id, delivered, created_at) │     │
│  │ Realtime: enabled                          │     │
│  └────────────────────────────────────────────┘     │
│                                                     │
│  CLI/MCP ──POST──► /rest/v1/pushes                  │
│                                                     │
│  iOS ──subscribe──► Realtime (INSERT on pushes)     │
│      ──UPDATE────► delivered = true                  │
└────────────────────────────────────────────────────┘
```

## Security Model

```
Threat Model:
┌──────────────────────────────────────────────────┐
│                                                   │
│  ✅ Content encrypted end-to-end (AES-256-GCM)   │
│  ✅ Keys derived via PBKDF2 (100k iterations)     │
│  ✅ QR pairing requires physical proximity        │
│  ✅ Keys stored in Keychain (iOS) / 0600 (CLI)    │
│  ✅ Cloud relay only sees encrypted blobs          │
│  ✅ Supabase RLS limits row access by device       │
│  ✅ Messages auto-expire after 7 days              │
│  ✅ No API keys or credentials in source code      │
│                                                   │
│  Attack surface:                                  │
│  • Local WiFi: same-network attacker can see      │
│    encrypted payloads but cannot decrypt           │
│  • Cloud: Supabase admin can see encrypted         │
│    payloads but cannot decrypt (no key access)     │
│  • Device theft: iOS Keychain protected by         │
│    device biometrics/passcode                      │
│                                                   │
└──────────────────────────────────────────────────┘
```
