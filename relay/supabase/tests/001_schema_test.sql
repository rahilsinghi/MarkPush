-- MarkPush Schema Verification Tests
-- Validates that both migrations (001_init + 002_auth_beta) applied correctly.
-- Run via: psql "$DATABASE_URL" -f 001_schema_test.sql

DO $$
DECLARE
    tbl TEXT;
    tables TEXT[] := ARRAY[
        'pushes', 'beta_whitelist', 'profiles', 'devices', 'push_tokens'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = tbl
        ) THEN
            RAISE EXCEPTION 'FAIL: table "%" does not exist', tbl;
        END IF;
    END LOOP;
    RAISE NOTICE 'PASS: all required tables exist';
END $$;

-- Verify pushes has user_id column from 002 migration
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'pushes'
          AND column_name = 'user_id'
    ) THEN
        RAISE EXCEPTION 'FAIL: pushes.user_id column missing (002 migration)';
    END IF;
    RAISE NOTICE 'PASS: pushes.user_id column exists';
END $$;

-- Verify devices.device_type CHECK constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE constraint_schema = 'public'
          AND constraint_name LIKE '%device_type%'
    ) THEN
        RAISE EXCEPTION 'FAIL: devices.device_type CHECK constraint missing';
    END IF;
    RAISE NOTICE 'PASS: devices.device_type CHECK constraint exists';
END $$;

-- Verify RLS is enabled on all tables
DO $$
DECLARE
    tbl TEXT;
    tables TEXT[] := ARRAY[
        'pushes', 'beta_whitelist', 'profiles', 'devices', 'push_tokens'
    ];
    rls_enabled BOOLEAN;
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        SELECT relrowsecurity INTO rls_enabled
        FROM pg_class
        WHERE relname = tbl AND relnamespace = 'public'::regnamespace;

        IF NOT rls_enabled THEN
            RAISE EXCEPTION 'FAIL: RLS not enabled on "%"', tbl;
        END IF;
    END LOOP;
    RAISE NOTICE 'PASS: RLS enabled on all tables';
END $$;

-- Verify key indexes exist
DO $$
DECLARE
    idx TEXT;
    indexes TEXT[] := ARRAY[
        'idx_pushes_receiver',
        'idx_pushes_user_id',
        'idx_beta_whitelist_email',
        'idx_devices_user_id',
        'idx_devices_device_id',
        'idx_push_tokens_user_id',
        'idx_push_tokens_device_id'
    ];
BEGIN
    FOREACH idx IN ARRAY indexes LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes
            WHERE schemaname = 'public' AND indexname = idx
        ) THEN
            RAISE EXCEPTION 'FAIL: index "%" does not exist', idx;
        END IF;
    END LOOP;
    RAISE NOTICE 'PASS: all required indexes exist';
END $$;

-- Verify triggers exist
DO $$
DECLARE
    trg TEXT;
    triggers TEXT[] := ARRAY[
        'trg_profiles_updated_at'
    ];
BEGIN
    FOREACH trg IN ARRAY triggers LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.triggers
            WHERE trigger_schema = 'public' AND trigger_name = trg
        ) THEN
            RAISE EXCEPTION 'FAIL: trigger "%" does not exist', trg;
        END IF;
    END LOOP;
    RAISE NOTICE 'PASS: all required triggers exist';
END $$;

-- Verify realtime publication includes pushes and devices
DO $$
DECLARE
    tbl TEXT;
    tables TEXT[] := ARRAY['pushes', 'devices'];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables
            WHERE pubname = 'supabase_realtime' AND tablename = tbl
        ) THEN
            RAISE EXCEPTION 'FAIL: table "%" not in supabase_realtime publication', tbl;
        END IF;
    END LOOP;
    RAISE NOTICE 'PASS: realtime publication includes pushes and devices';
END $$;

-- Verify unique constraints
DO $$
BEGIN
    -- beta_whitelist.email unique
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'beta_whitelist'
          AND indexdef LIKE '%UNIQUE%'
    ) THEN
        RAISE EXCEPTION 'FAIL: beta_whitelist.email unique constraint missing';
    END IF;

    -- devices (user_id, device_id) unique
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'devices'
          AND indexdef LIKE '%UNIQUE%'
    ) THEN
        RAISE EXCEPTION 'FAIL: devices (user_id, device_id) unique constraint missing';
    END IF;

    -- push_tokens.token unique
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'push_tokens'
          AND indexdef LIKE '%UNIQUE%'
    ) THEN
        RAISE EXCEPTION 'FAIL: push_tokens.token unique constraint missing';
    END IF;

    RAISE NOTICE 'PASS: all unique constraints exist';
END $$;
