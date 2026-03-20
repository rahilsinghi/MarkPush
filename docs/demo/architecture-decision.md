# ADR-007: Raw TCP over WebSocket for WiFi Transport

**Status:** Accepted
**Date:** 2025-12-14
**Author:** Rahil Singhi

## Context

MarkPush needs a local transport for pushing markdown from CLI to the iOS app over WiFi. The transport must support:

- Encrypted binary payloads (AES-256-GCM ciphertext)
- Single-shot message delivery (not streaming)
- Zero configuration — no hardcoded IPs or ports
- Sub-second latency on LAN

## Options Considered

### Option A: WebSocket (gorilla/websocket + NWProtocolWebSocket)

| Aspect | Assessment |
|--------|------------|
| Framing | Built-in message framing |
| Encryption | TLS available via wss:// |
| Compatibility | gorilla/websocket is battle-tested |
| iOS support | `NWProtocolWebSocket` in Network.framework |

**Problem discovered:** `NWProtocolWebSocket` sends a non-standard handshake that `gorilla/websocket` rejects. The HTTP Upgrade headers differ in casing and extension negotiation. No clean workaround without patching either side.

### Option B: Raw TCP with length-prefixed framing

| Aspect | Assessment |
|--------|------------|
| Framing | Manual: 4-byte length prefix + payload |
| Encryption | Application-layer AES-256-GCM (already implemented) |
| Compatibility | TCP works everywhere |
| iOS support | `NWConnection` with TCP is first-class |

**Advantage:** Zero dependency on HTTP upgrade negotiation. Both sides speak the same simple protocol: `[4 bytes: payload length][payload bytes]`.

### Option C: gRPC

Rejected early — too heavy for single-shot LAN messages. Adds protobuf compilation step and ~8MB to binary size.

## Decision

**Option B — Raw TCP with length-prefixed framing.**

The WebSocket handshake incompatibility between Go and Apple's Network.framework is a fundamental mismatch, not a bug we can patch. Raw TCP with our own framing is simpler, faster, and has zero cross-platform compatibility risk.

Combined with mDNS service discovery (Bonjour), the full flow is:

```
CLI                          iOS App
 │                              │
 │  mDNS: discover _markpush   │
 │──────────────────────────────│
 │           service found      │
 │◄─────────────────────────────│
 │                              │
 │  TCP: connect to host:port   │
 │──────────────────────────────│
 │  [4B len][encrypted payload] │
 │──────────────────────────────│
 │           ACK                │
 │◄─────────────────────────────│
```

## Consequences

- We own the framing protocol — must handle partial reads and length validation
- No TLS at transport layer — acceptable because payloads are already AES-256-GCM encrypted at the application layer
- Simpler debugging with `tcpdump` — raw TCP is easier to inspect than WebSocket frames
- iOS uses `.any` port (OS-assigned) to avoid "Address already in use" on app restart
