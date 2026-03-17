-- MarkPush RLS Tests: pushes table
-- Tests the dual-path RLS (legacy device_id GUC + JWT auth.uid()).
-- Run via: psql "$DATABASE_URL" -f 002_rls_pushes_test.sql

-- Test 1: Legacy path — receiver can read own pushes via device_id GUC
BEGIN;
    INSERT INTO public.pushes (sender_id, receiver_id, payload)
    VALUES ('cli-test', 'device-A', 'encrypted-blob-1');

    -- Set GUC *before* switching role
    SET LOCAL app.device_id = 'device-A';
    SET LOCAL ROLE anon;

    DO $$
    DECLARE cnt INT;
    BEGIN
        SELECT count(*) INTO cnt FROM public.pushes WHERE receiver_id = 'device-A';
        IF cnt < 1 THEN
            RAISE EXCEPTION 'FAIL: legacy receiver cannot read own pushes';
        END IF;
        RAISE NOTICE 'PASS: legacy receiver can read own pushes';
    END $$;
ROLLBACK;

-- Test 2: Legacy path — different device sees nothing
BEGIN;
    INSERT INTO public.pushes (sender_id, receiver_id, payload)
    VALUES ('cli-test', 'device-A', 'encrypted-blob-2');

    SET LOCAL app.device_id = 'device-B';
    SET LOCAL ROLE anon;

    DO $$
    DECLARE cnt INT;
    BEGIN
        SELECT count(*) INTO cnt FROM public.pushes;
        IF cnt != 0 THEN
            RAISE EXCEPTION 'FAIL: legacy device-B can see device-A pushes';
        END IF;
        RAISE NOTICE 'PASS: legacy device isolation works';
    END $$;
ROLLBACK;

-- Test 3: JWT path — authenticated user can read own pushes
BEGIN;
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000',
         'alice@test.com', '', now(), now(), now(), 'authenticated', 'authenticated');
    -- profile auto-created by handle_new_user trigger

    INSERT INTO public.pushes (sender_id, receiver_id, payload, user_id)
    VALUES ('cli-test', 'device-X', 'encrypted-blob-3', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

    SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","email":"alice@test.com"}';
    SET LOCAL ROLE authenticated;

    DO $$
    DECLARE cnt INT;
    BEGIN
        SELECT count(*) INTO cnt FROM public.pushes;
        IF cnt < 1 THEN
            RAISE EXCEPTION 'FAIL: JWT user cannot read own pushes';
        END IF;
        RAISE NOTICE 'PASS: JWT user can read own pushes';
    END $$;
ROLLBACK;

-- Test 4: JWT path — different user sees nothing
BEGIN;
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000',
         'alice@test.com', '', now(), now(), now(), 'authenticated', 'authenticated');
    -- profile auto-created by handle_new_user trigger

    INSERT INTO public.pushes (sender_id, receiver_id, payload, user_id)
    VALUES ('cli-test', 'device-X', 'encrypted-blob-4', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

    SET LOCAL request.jwt.claims = '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","email":"bob@test.com"}';
    SET LOCAL ROLE authenticated;

    DO $$
    DECLARE cnt INT;
    BEGIN
        SELECT count(*) INTO cnt FROM public.pushes;
        IF cnt != 0 THEN
            RAISE EXCEPTION 'FAIL: JWT user can see another users pushes';
        END IF;
        RAISE NOTICE 'PASS: JWT user isolation works';
    END $$;
ROLLBACK;

-- Test 5: JWT path — user can insert pushes with own user_id
BEGIN;
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000',
         'alice@test.com', '', now(), now(), now(), 'authenticated', 'authenticated');
    -- profile auto-created by handle_new_user trigger

    SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","email":"alice@test.com"}';
    SET LOCAL ROLE authenticated;

    DO $$
    BEGIN
        INSERT INTO public.pushes (sender_id, receiver_id, payload, user_id)
        VALUES ('mcp-test', 'device-Y', 'blob', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
        RAISE NOTICE 'PASS: JWT user can insert own pushes';
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'FAIL: JWT user cannot insert own pushes: %', SQLERRM;
    END $$;
ROLLBACK;

-- Test 6: JWT path — user can update delivery status on own pushes
BEGIN;
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000',
         'alice@test.com', '', now(), now(), now(), 'authenticated', 'authenticated');
    -- profile auto-created by handle_new_user trigger

    INSERT INTO public.pushes (id, sender_id, receiver_id, payload, user_id)
    VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'cli-test', 'device-X', 'blob',
            'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

    SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","email":"alice@test.com"}';
    SET LOCAL ROLE authenticated;

    DO $$
    DECLARE updated INT;
    BEGIN
        UPDATE public.pushes SET delivered = true
        WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
        GET DIAGNOSTICS updated = ROW_COUNT;
        IF updated != 1 THEN
            RAISE EXCEPTION 'FAIL: JWT user cannot update own push delivery status';
        END IF;
        RAISE NOTICE 'PASS: JWT user can update own push delivery status';
    END $$;
ROLLBACK;

-- Test 7: Legacy path — receiver can update delivery status
BEGIN;
    INSERT INTO public.pushes (id, sender_id, receiver_id, payload)
    VALUES ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'cli-test', 'device-A', 'blob');

    SET LOCAL app.device_id = 'device-A';
    SET LOCAL ROLE anon;

    DO $$
    DECLARE updated INT;
    BEGIN
        UPDATE public.pushes SET delivered = true
        WHERE id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
        GET DIAGNOSTICS updated = ROW_COUNT;
        IF updated != 1 THEN
            RAISE EXCEPTION 'FAIL: legacy receiver cannot update delivery status';
        END IF;
        RAISE NOTICE 'PASS: legacy receiver can update delivery status';
    END $$;
ROLLBACK;

-- Test 8: Legacy path — wrong device cannot update
BEGIN;
    INSERT INTO public.pushes (id, sender_id, receiver_id, payload)
    VALUES ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'cli-test', 'device-A', 'blob');

    SET LOCAL app.device_id = 'device-B';
    SET LOCAL ROLE anon;

    DO $$
    DECLARE updated INT;
    BEGIN
        UPDATE public.pushes SET delivered = true
        WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
        GET DIAGNOSTICS updated = ROW_COUNT;
        IF updated != 0 THEN
            RAISE EXCEPTION 'FAIL: wrong device can update delivery status';
        END IF;
        RAISE NOTICE 'PASS: wrong device cannot update delivery status';
    END $$;
ROLLBACK;
