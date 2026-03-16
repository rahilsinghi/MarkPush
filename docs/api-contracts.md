# API Contracts

## WebSocket Message Protocol

All messages are JSON. Encryption wraps the `content` field only.

### Base Message

```json
{
  "version": "1",
  "type": "push | pair_init | pair_ack | ping | pong | ack | error",
  "id": "uuid-v4",
  "timestamp": "2026-03-16T12:00:00Z"
}
```

### Push Message

```json
{
  "version": "1",
  "type": "push",
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2026-03-16T12:00:00Z",
  "title": "Authentication Design",
  "tags": ["backend", "security"],
  "source": "claude",
  "word_count": 1234,
  "content": "base64-encoded-markdown-or-encrypted-blob",
  "encrypted": true,
  "sender_id": "cli-device-uuid",
  "sender_name": "MacBook-Pro"
}
```

### Ack Message

```json
{
  "version": "1",
  "type": "ack",
  "id": "uuid-v4",
  "timestamp": "2026-03-16T12:00:01Z",
  "ref_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "received"
}
```

### Pair Init (QR Payload)

```json
{
  "v": "1",
  "s": "base64-random-32-bytes",
  "h": "192.168.1.42",
  "p": 54321,
  "id": "cli-device-uuid",
  "name": "MacBook-Pro"
}
```

## Supabase Cloud Relay

### Table: `pushes`

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| created_at | timestamptz | Auto-set |
| sender_id | text | CLI device UUID |
| receiver_id | text | iOS device UUID |
| payload | text | Base64 AES-256-GCM encrypted PushMessage JSON |
| delivered | boolean | Default false |
| delivered_at | timestamptz | Set when iOS acknowledges |
| expires_at | timestamptz | Default now() + 7 days |

### Row-Level Security
- Devices can only read pushes addressed to their `receiver_id`
- Realtime subscription filtered by `receiver_id`

### REST API
- `POST /rest/v1/pushes` — CLI inserts encrypted push
- iOS uses Realtime subscription, not polling
