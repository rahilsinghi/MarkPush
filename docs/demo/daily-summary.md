# Daily Summary — Mar 18

## Completed

- Shipped auth middleware refactor to staging (PR #142)
- Fixed race condition in WebSocket connection pool — was dropping 1 in ~200 messages under load
- Reviewed and approved Sarah's RLS policy migration for the `push_tokens` table
- Updated Grafana dashboard with new latency percentiles (p95, p99)

## In Progress

- **Cloud relay load testing** — running k6 scripts against staging, targeting 500 concurrent pushes. Initial results: p95 latency at 340ms, goal is under 200ms. Bottleneck looks like Supabase Realtime fanout.
- **MCP server v0.3.0** — adding `watch_directory` tool and `push_url` for pushing web content

## Blockers

- Waiting on Apple Developer enrollment approval (submitted Mar 15, typically 24-48 hours but still pending). Blocks TestFlight distribution.
- Need DevOps to bump Supabase connection pool limit from 20 to 50 — current limit causes 503s during load tests.

## Tomorrow

- [ ] Profile Supabase Realtime bottleneck — check if batching channel broadcasts helps
- [ ] Write E2E test for full push flow: CLI encrypt -> cloud relay -> iOS decrypt -> SwiftData persist
- [ ] Draft v1.0 release checklist
