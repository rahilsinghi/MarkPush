# Pairing Protocol

## Flow

```
CLI                                 iOS App
 │                                     │
 │── (1) markpush pair ─────────────── │
 │    Generates 32-byte secret         │
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
 │  CLI saves: ~/.config/markpush/devices.toml
 │  iOS saves: Keychain                │
```

## Key Derivation

```
shared_key = PBKDF2-SHA256(
    password: pairing_secret,     // 32 random bytes from QR
    salt:     ios_device_id,      // UUID of the iOS device
    iterations: 100000,
    key_length: 32                // 256 bits for AES-256
)
```

## Security Properties

- **Secret is ephemeral** — generated fresh for each pairing, never stored
- **Key is deterministic** — both sides derive the same key independently
- **QR is local** — displayed on terminal screen, requires physical proximity
- **Key storage** — CLI uses file permissions (0600), iOS uses Keychain
- **No server involved** — pairing is fully peer-to-peer over local HTTP

## Unpairing

- CLI: `markpush unpair [device-name]` removes from `devices.toml`
- iOS: Settings → Devices → Swipe to delete, removes from Keychain
