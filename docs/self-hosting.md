# Self-Hosting the Cloud Relay

The cloud relay is optional — MarkPush works fully over local WiFi. Use the cloud relay when your CLI and iOS device are on different networks.

## Quick Start with Supabase

1. Create a free project at [supabase.com](https://supabase.com)
2. Run the migration:
   ```bash
   cd relay/supabase
   supabase db push
   ```
3. Copy your project URL and anon key to `~/.config/markpush/config.toml`:
   ```toml
   [cloud]
   supabase_url = "https://your-project.supabase.co"
   supabase_key = "your-anon-key"
   ```
4. In the iOS app, go to Settings → Cloud Relay and enter the same URL and key

## Data Retention

- Pushes auto-expire after 7 days (configurable via `expires_at`)
- All content is end-to-end encrypted — Supabase only sees encrypted blobs
- Set up a pg_cron job to clean expired rows:
  ```sql
  select cron.schedule('cleanup-expired', '0 */6 * * *',
    $$delete from public.pushes where expires_at < now()$$
  );
  ```

## Docker (Full Self-Host)

For running your own Supabase instance:

```bash
cd relay
docker compose up -d
```

See the [Supabase self-hosting guide](https://supabase.com/docs/guides/self-hosting) for details.
