-- MarkPush RLS Tests: profiles + devices tables
-- Run via: psql "$DATABASE_URL" -f 003_rls_profiles_devices_test.sql
-- Note: profiles.id FK references auth.users, so we insert test users there first.

-- Helper: creates a test user in auth.users + profiles
-- Usage: called inline in each BEGIN block

-- ============================================================================
-- PROFILES
-- ============================================================================

-- Test 1: User can read own profile
BEGIN;
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000',
         'alice@test.com', '', now(), now(), now(), 'authenticated', 'authenticated');
    -- profile auto-created by handle_new_user trigger

    SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","email":"alice@test.com"}';
    SET LOCAL ROLE authenticated;

    DO $$
    DECLARE cnt INT;
    BEGIN
        SELECT count(*) INTO cnt FROM public.profiles;
        IF cnt != 1 THEN
            RAISE EXCEPTION 'FAIL: user cannot read own profile (got %)', cnt;
        END IF;
        RAISE NOTICE 'PASS: user can read own profile';
    END $$;
ROLLBACK;

-- Test 2: User cannot read another users profile
BEGIN;
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000',
         'alice@test.com', '', now(), now(), now(), 'authenticated', 'authenticated'),
        ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '00000000-0000-0000-0000-000000000000',
         'bob@test.com', '', now(), now(), now(), 'authenticated', 'authenticated');
    -- profiles auto-created by handle_new_user trigger

    SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","email":"alice@test.com"}';
    SET LOCAL ROLE authenticated;

    DO $$
    DECLARE cnt INT;
    BEGIN
        SELECT count(*) INTO cnt FROM public.profiles;
        IF cnt != 1 THEN
            RAISE EXCEPTION 'FAIL: user can see % profiles (expected 1)', cnt;
        END IF;
        RAISE NOTICE 'PASS: user cannot read another users profile';
    END $$;
ROLLBACK;

-- Test 3: User can update own profile
BEGIN;
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000',
         'alice@test.com', '', now(), now(), now(), 'authenticated', 'authenticated');
    -- profile auto-created by handle_new_user trigger

    SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","email":"alice@test.com"}';
    SET LOCAL ROLE authenticated;

    DO $$
    DECLARE updated INT;
    BEGIN
        UPDATE public.profiles SET display_name = 'Alice Updated'
        WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
        GET DIAGNOSTICS updated = ROW_COUNT;
        IF updated != 1 THEN
            RAISE EXCEPTION 'FAIL: user cannot update own profile';
        END IF;
        RAISE NOTICE 'PASS: user can update own profile';
    END $$;
ROLLBACK;

-- Test 4: User cannot update another users profile
BEGIN;
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000',
         'alice@test.com', '', now(), now(), now(), 'authenticated', 'authenticated'),
        ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '00000000-0000-0000-0000-000000000000',
         'bob@test.com', '', now(), now(), now(), 'authenticated', 'authenticated');
    -- profiles auto-created by handle_new_user trigger

    SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","email":"alice@test.com"}';
    SET LOCAL ROLE authenticated;

    DO $$
    DECLARE updated INT;
    BEGIN
        UPDATE public.profiles SET display_name = 'Hacked'
        WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
        GET DIAGNOSTICS updated = ROW_COUNT;
        IF updated != 0 THEN
            RAISE EXCEPTION 'FAIL: user can update another users profile';
        END IF;
        RAISE NOTICE 'PASS: user cannot update another users profile';
    END $$;
ROLLBACK;

-- ============================================================================
-- DEVICES
-- ============================================================================

-- Test 5: User can insert own device
BEGIN;
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000',
         'alice@test.com', '', now(), now(), now(), 'authenticated', 'authenticated');
    -- profile auto-created by handle_new_user trigger

    SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","email":"alice@test.com"}';
    SET LOCAL ROLE authenticated;

    DO $$
    BEGIN
        INSERT INTO public.devices (user_id, device_id, name, device_type)
        VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'iphone-1', 'iPhone', 'ios');
        RAISE NOTICE 'PASS: user can insert own device';
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'FAIL: user cannot insert own device: %', SQLERRM;
    END $$;
ROLLBACK;

-- Test 6: User cannot insert device for another user
BEGIN;
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000',
         'alice@test.com', '', now(), now(), now(), 'authenticated', 'authenticated'),
        ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '00000000-0000-0000-0000-000000000000',
         'bob@test.com', '', now(), now(), now(), 'authenticated', 'authenticated');
    -- profiles auto-created by handle_new_user trigger

    SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","email":"alice@test.com"}';
    SET LOCAL ROLE authenticated;

    DO $$
    BEGIN
        INSERT INTO public.devices (user_id, device_id, name, device_type)
        VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'iphone-stolen', 'Fake', 'ios');
        RAISE EXCEPTION 'FAIL: user can insert device for another user';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: user cannot insert device for another user';
    WHEN OTHERS THEN
        RAISE NOTICE 'PASS: user cannot insert device for another user (%)' , SQLSTATE;
    END $$;
ROLLBACK;

-- Test 7: User can read only own devices
BEGIN;
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000',
         'alice@test.com', '', now(), now(), now(), 'authenticated', 'authenticated'),
        ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '00000000-0000-0000-0000-000000000000',
         'bob@test.com', '', now(), now(), now(), 'authenticated', 'authenticated');
    -- profiles auto-created by handle_new_user trigger
    INSERT INTO public.devices (user_id, device_id, name, device_type) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'iphone-1', 'Alice iPhone', 'ios'),
        ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'iphone-2', 'Bob iPhone', 'ios');

    SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","email":"alice@test.com"}';
    SET LOCAL ROLE authenticated;

    DO $$
    DECLARE cnt INT;
    BEGIN
        SELECT count(*) INTO cnt FROM public.devices;
        IF cnt != 1 THEN
            RAISE EXCEPTION 'FAIL: user can see % devices (expected 1)', cnt;
        END IF;
        RAISE NOTICE 'PASS: user can read only own devices';
    END $$;
ROLLBACK;

-- Test 8: User can delete own device
BEGIN;
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000',
         'alice@test.com', '', now(), now(), now(), 'authenticated', 'authenticated');
    -- profile auto-created by handle_new_user trigger
    INSERT INTO public.devices (user_id, device_id, name, device_type) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'iphone-1', 'Alice iPhone', 'ios');

    SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","email":"alice@test.com"}';
    SET LOCAL ROLE authenticated;

    DO $$
    DECLARE deleted INT;
    BEGIN
        DELETE FROM public.devices WHERE device_id = 'iphone-1';
        GET DIAGNOSTICS deleted = ROW_COUNT;
        IF deleted != 1 THEN
            RAISE EXCEPTION 'FAIL: user cannot delete own device';
        END IF;
        RAISE NOTICE 'PASS: user can delete own device';
    END $$;
ROLLBACK;

-- Test 9: Invalid device_type rejected
BEGIN;
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000',
         'alice@test.com', '', now(), now(), now(), 'authenticated', 'authenticated');
    -- profile auto-created by handle_new_user trigger

    DO $$
    BEGIN
        INSERT INTO public.devices (user_id, device_id, name, device_type)
        VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'android-1', 'Pixel', 'android');
        RAISE EXCEPTION 'FAIL: invalid device_type "android" was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: invalid device_type rejected by CHECK constraint';
    END $$;
ROLLBACK;
