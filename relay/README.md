# MarkPush Cloud Relay

Optional Supabase-based cloud relay for pushing markdown when your CLI and iOS device are on different networks.

## Setup

1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Install the Supabase CLI:
   ```bash
   brew install supabase/tap/supabase
   ```
3. Link your project:
   ```bash
   cd relay/supabase
   supabase link --project-ref your-project-ref
   ```
4. Run the migration:
   ```bash
   supabase db push
   ```
5. Configure the CLI:
   ```bash
   markpush config set cloud.supabase_url "https://your-project.supabase.co"
   markpush config set cloud.supabase_key "your-anon-key"
   ```

## Security

- All message content is end-to-end encrypted (AES-256-GCM)
- Supabase only sees encrypted blobs
- Row-level security ensures devices can only read their own messages
- Messages auto-expire after 7 days

## Self-Hosting

See [docs/self-hosting.md](../docs/self-hosting.md) for running your own Supabase instance.
