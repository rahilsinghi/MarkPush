-- MarkPush Beta Auth Migration
-- Adds beta whitelist, user profiles, device pairing, and push token tables.
-- Updates pushes RLS to support both legacy device_id header and new JWT auth
-- during the migration period.
--
-- Depends on: 001_init.sql

-- ---------------------------------------------------------------------------
-- 1. BETA WHITELIST
-- ---------------------------------------------------------------------------

create table public.beta_whitelist (
    id          uuid primary key default gen_random_uuid(),
    email       text unique not null,
    invited_at  timestamptz not null default now(),
    invited_by  text
);

comment on table public.beta_whitelist is
    'Emails approved to sign up during the closed beta period.';

-- Only service-role callers (backend/admin) can manage the whitelist.
-- Authenticated users may check whether their own email is listed.
alter table public.beta_whitelist enable row level security;

create policy "service role full access to beta_whitelist"
    on public.beta_whitelist
    as permissive
    for all
    to service_role
    using (true)
    with check (true);

create policy "authenticated users can check their own whitelist entry"
    on public.beta_whitelist
    for select
    to authenticated
    using (email = (select auth.email()));

-- ---------------------------------------------------------------------------
-- 2. PROFILES
-- Mirrors auth.users with app-level metadata.
-- ---------------------------------------------------------------------------

create table public.profiles (
    id           uuid primary key references auth.users on delete cascade,
    email        text,
    display_name text,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);

comment on table public.profiles is
    'Application-level profile data for every authenticated user.';

alter table public.profiles enable row level security;

-- Users can read and update only their own profile.
create policy "users can read own profile"
    on public.profiles
    for select
    to authenticated
    using (id = (select auth.uid()));

create policy "users can update own profile"
    on public.profiles
    for update
    to authenticated
    using (id = (select auth.uid()))
    with check (id = (select auth.uid()));

-- Service role retains full access for admin operations.
create policy "service role full access to profiles"
    on public.profiles
    as permissive
    for all
    to service_role
    using (true)
    with check (true);

-- Keep updated_at current automatically.
create or replace function public.set_updated_at()
    returns trigger
    language plpgsql
    security definer
    set search_path = ''
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger trg_profiles_updated_at
    before update on public.profiles
    for each row
    execute function public.set_updated_at();

-- Auto-create a profile row whenever a new user signs up.
create or replace function public.handle_new_user()
    returns trigger
    language plpgsql
    security definer
    set search_path = ''
as $$
begin
    insert into public.profiles (id, email, display_name)
    values (
        new.id,
        new.email,
        coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1))
    )
    on conflict (id) do nothing;
    return new;
end;
$$;

create trigger trg_auth_users_create_profile
    after insert on auth.users
    for each row
    execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 3. DEVICES
-- Represents a paired iOS app or CLI/MCP client.
-- ---------------------------------------------------------------------------

create table public.devices (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references public.profiles on delete cascade,
    device_id   text not null,
    name        text,
    device_type text check (device_type in ('ios', 'cli', 'mcp')),
    paired_at   timestamptz not null default now(),
    last_seen_at timestamptz,
    unique (user_id, device_id)
);

comment on table public.devices is
    'Devices (iOS, CLI, MCP) paired to a user account.';

alter table public.devices enable row level security;

create policy "users can read own devices"
    on public.devices
    for select
    to authenticated
    using (user_id = (select auth.uid()));

create policy "users can insert own devices"
    on public.devices
    for insert
    to authenticated
    with check (user_id = (select auth.uid()));

create policy "users can update own devices"
    on public.devices
    for update
    to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

create policy "users can delete own devices"
    on public.devices
    for delete
    to authenticated
    using (user_id = (select auth.uid()));

create policy "service role full access to devices"
    on public.devices
    as permissive
    for all
    to service_role
    using (true)
    with check (true);

-- ---------------------------------------------------------------------------
-- 4. PUSH TOKENS
-- APNs/FCM tokens linked to a device.
-- ---------------------------------------------------------------------------

create table public.push_tokens (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null references public.profiles on delete cascade,
    device_id  uuid references public.devices on delete set null,
    token      text not null,
    platform   text not null default 'ios',
    created_at timestamptz not null default now(),
    unique (token)
);

comment on table public.push_tokens is
    'APNs / FCM push notification tokens for registered devices.';

alter table public.push_tokens enable row level security;

create policy "users can read own push tokens"
    on public.push_tokens
    for select
    to authenticated
    using (user_id = (select auth.uid()));

create policy "users can insert own push tokens"
    on public.push_tokens
    for insert
    to authenticated
    with check (user_id = (select auth.uid()));

create policy "users can delete own push tokens"
    on public.push_tokens
    for delete
    to authenticated
    using (user_id = (select auth.uid()));

create policy "service role full access to push_tokens"
    on public.push_tokens
    as permissive
    for all
    to service_role
    using (true)
    with check (true);

-- ---------------------------------------------------------------------------
-- 5. ALTER PUSHES TABLE
-- Add user_id for JWT-based routing alongside legacy receiver_id/sender_id.
-- ---------------------------------------------------------------------------

alter table public.pushes
    add column if not exists user_id uuid references public.profiles on delete set null;

comment on column public.pushes.user_id is
    'Set when the push was created via JWT auth. NULL for legacy device-ID pushes.';

-- ---------------------------------------------------------------------------
-- 6. UPDATE PUSHES RLS
-- Support both legacy app.device_id GUC (CLI/MCP) and new JWT auth (iOS app)
-- during the migration window. Once all clients are upgraded, the GUC branches
-- can be dropped in a future migration.
-- ---------------------------------------------------------------------------

-- Drop existing policies defined in 001_init.sql so we can replace them.
drop policy if exists "receivers can read their own pushes" on public.pushes;
drop policy if exists "senders can insert pushes" on public.pushes;
drop policy if exists "receivers can update delivery status" on public.pushes;

-- SELECT: authenticated JWT users see pushes addressed to their user_id;
--         legacy clients fall back to the device_id GUC.
create policy "receivers can read their own pushes"
    on public.pushes
    for select
    using (
        (
            -- New JWT path: push was tagged with the authenticated user's id.
            auth.uid() is not null
            and user_id = (select auth.uid())
        )
        or
        (
            -- Legacy path: no JWT session, rely on the device_id GUC set by the
            -- relay's service-role middleware.
            auth.uid() is null
            and receiver_id = current_setting('app.device_id', true)
        )
    );

-- INSERT: authenticated users may push to any destination (the relay validates
--         the target); legacy anon inserts continue to work unconditionally.
create policy "senders can insert pushes"
    on public.pushes
    for insert
    with check (
        (
            auth.uid() is not null
            and (user_id = (select auth.uid()) or user_id is null)
        )
        or auth.uid() is null
    );

-- UPDATE (delivery status): same dual-path as SELECT.
create policy "receivers can update delivery status"
    on public.pushes
    for update
    using (
        (
            auth.uid() is not null
            and user_id = (select auth.uid())
        )
        or
        (
            auth.uid() is null
            and receiver_id = current_setting('app.device_id', true)
        )
    )
    with check (
        (
            auth.uid() is not null
            and user_id = (select auth.uid())
        )
        or
        (
            auth.uid() is null
            and receiver_id = current_setting('app.device_id', true)
        )
    );

-- ---------------------------------------------------------------------------
-- 7. INDEXES
-- ---------------------------------------------------------------------------

-- beta_whitelist: fast email lookups during sign-up gate check.
create index idx_beta_whitelist_email on public.beta_whitelist(email);

-- profiles: RLS policy column.
create index idx_profiles_id on public.profiles(id);

-- devices: RLS policy column + device_id lookups from legacy relay code.
create index idx_devices_user_id      on public.devices(user_id);
create index idx_devices_device_id    on public.devices(device_id);

-- push_tokens: RLS policy column + token lookups for APNs delivery.
create index idx_push_tokens_user_id  on public.push_tokens(user_id);
create index idx_push_tokens_device_id on public.push_tokens(device_id);

-- pushes: user_id for JWT-based receiver polling.
create index idx_pushes_user_id on public.pushes(user_id, delivered, created_at);

-- ---------------------------------------------------------------------------
-- 8. REALTIME
-- ---------------------------------------------------------------------------

-- Clients subscribe to their own device list to detect new pairings.
alter publication supabase_realtime add table public.devices;
