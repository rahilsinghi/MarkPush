-- MarkPush Cloud Relay Schema
-- Stores encrypted push messages for delivery to iOS devices.

create table public.pushes (
    id          uuid primary key default gen_random_uuid(),
    created_at  timestamptz default now(),

    -- Routing
    sender_id   text not null,
    receiver_id text not null,

    -- Content (always encrypted)
    payload     text not null,

    -- Delivery status
    delivered   boolean default false,
    delivered_at timestamptz,

    -- TTL: auto-delete after 7 days
    expires_at  timestamptz default (now() + interval '7 days')
);

-- Row-level security: devices can only read pushes addressed to them.
alter table public.pushes enable row level security;

create policy "receivers can read their own pushes"
    on public.pushes for select
    using (receiver_id = current_setting('app.device_id', true));

create policy "senders can insert pushes"
    on public.pushes for insert
    with check (true);

create policy "receivers can update delivery status"
    on public.pushes for update
    using (receiver_id = current_setting('app.device_id', true))
    with check (receiver_id = current_setting('app.device_id', true));

-- Index for efficient polling.
create index idx_pushes_receiver on public.pushes(receiver_id, delivered, created_at);

-- Enable Realtime for this table.
alter publication supabase_realtime add table public.pushes;
