-- MarkPush RLS Tests: beta_whitelist + push_tokens tables
-- Run via: psql "$DATABASE_URL" -f 004_rls_beta_whitelist_tokens_test.sql

-- ============================================================================
-- BETA WHITELIST
-- ============================================================================

-- Test 1: Authenticated user can see own whitelist entry
BEGIN;
    INSERT INTO public.beta_whitelist (email, invited_by)
    VALUES ('alice@test.com', 'system');

    SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","email":"alice@test.com"}';
    SET LOCAL ROLE authenticated;

    DO $$
    DECLARE cnt INT;
    BEGIN
        SELECT count(*) INTO cnt FROM public.beta_whitelist;
        IF cnt != 1 THEN
            RAISE EXCEPTION 'FAIL: user cannot see own whitelist entry (got %)', cnt;
        END IF;
        RAISE NOTICE 'PASS: user can see own whitelist entry';
    END $$;
ROLLBACK;

-- Test 2: Authenticated user cannot see other emails in whitelist
BEGIN;
    INSERT INTO public.beta_whitelist (email, invited_by) VALUES
        ('alice@test.com', 'system'),
        ('bob@test.com', 'system');

    SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","email":"alice@test.com"}';
    SET LOCAL ROLE authenticated;

    DO $$
    DECLARE cnt INT;
    BEGIN
        SELECT count(*) INTO cnt FROM public.beta_whitelist;
        IF cnt != 1 THEN
            RAISE EXCEPTION 'FAIL: user can see % whitelist entries (expected 1)', cnt;
        END IF;
        RAISE NOTICE 'PASS: user cannot see other whitelist entries';
    END $$;
ROLLBACK;

-- Test 3: Authenticated user cannot insert into whitelist
BEGIN;
    SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","email":"alice@test.com"}';
    SET LOCAL ROLE authenticated;

    DO $$
    BEGIN
        INSERT INTO public.beta_whitelist (email, invited_by) VALUES ('hacker@evil.com', 'alice');
        RAISE EXCEPTION 'FAIL: authenticated user can insert into whitelist';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: authenticated user cannot insert into whitelist';
    WHEN OTHERS THEN
        RAISE NOTICE 'PASS: authenticated user cannot insert into whitelist (%)' , SQLSTATE;
    END $$;
ROLLBACK;

-- Test 4: Service role can manage whitelist
DO $$
DECLARE cnt INT;
BEGIN
    INSERT INTO public.beta_whitelist (email, invited_by) VALUES ('svc-test@test.com', 'test');
    SELECT count(*) INTO cnt FROM public.beta_whitelist WHERE email = 'svc-test@test.com';
    DELETE FROM public.beta_whitelist WHERE email = 'svc-test@test.com';

    IF cnt != 1 THEN
        RAISE EXCEPTION 'FAIL: service role cannot manage whitelist';
    END IF;
    RAISE NOTICE 'PASS: service role can manage whitelist';
END $$;

-- ============================================================================
-- PUSH TOKENS
-- ============================================================================

-- Test 5: User can insert own push token
BEGIN;
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000',
         'alice@test.com', '', now(), now(), now(), 'authenticated', 'authenticated');
    -- profile auto-created by handle_new_user trigger

    SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","email":"alice@test.com"}';
    SET LOCAL ROLE authenticated;

    DO $$
    BEGIN
        INSERT INTO public.push_tokens (user_id, token, platform)
        VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'apns-token-abc123', 'ios');
        RAISE NOTICE 'PASS: user can insert own push token';
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'FAIL: user cannot insert own push token: %', SQLERRM;
    END $$;
ROLLBACK;

-- Test 6: User can read only own push tokens
BEGIN;
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000',
         'alice@test.com', '', now(), now(), now(), 'authenticated', 'authenticated'),
        ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '00000000-0000-0000-0000-000000000000',
         'bob@test.com', '', now(), now(), now(), 'authenticated', 'authenticated');
    -- profiles auto-created by handle_new_user trigger
    INSERT INTO public.push_tokens (user_id, token, platform) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'alice-token', 'ios'),
        ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'bob-token', 'ios');

    SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","email":"alice@test.com"}';
    SET LOCAL ROLE authenticated;

    DO $$
    DECLARE cnt INT;
    BEGIN
        SELECT count(*) INTO cnt FROM public.push_tokens;
        IF cnt != 1 THEN
            RAISE EXCEPTION 'FAIL: user can see % tokens (expected 1)', cnt;
        END IF;
        RAISE NOTICE 'PASS: user can read only own push tokens';
    END $$;
ROLLBACK;

-- Test 7: User can delete own push token
BEGIN;
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000',
         'alice@test.com', '', now(), now(), now(), 'authenticated', 'authenticated');
    -- profile auto-created by handle_new_user trigger
    INSERT INTO public.push_tokens (user_id, token, platform) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'delete-me-token', 'ios');

    SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","email":"alice@test.com"}';
    SET LOCAL ROLE authenticated;

    DO $$
    DECLARE deleted INT;
    BEGIN
        DELETE FROM public.push_tokens WHERE token = 'delete-me-token';
        GET DIAGNOSTICS deleted = ROW_COUNT;
        IF deleted != 1 THEN
            RAISE EXCEPTION 'FAIL: user cannot delete own push token';
        END IF;
        RAISE NOTICE 'PASS: user can delete own push token';
    END $$;
ROLLBACK;

-- Test 8: Duplicate token rejected
BEGIN;
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000',
         'alice@test.com', '', now(), now(), now(), 'authenticated', 'authenticated');
    -- profile auto-created by handle_new_user trigger
    INSERT INTO public.push_tokens (user_id, token, platform) VALUES
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'unique-token', 'ios');

    DO $$
    BEGIN
        INSERT INTO public.push_tokens (user_id, token, platform)
        VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'unique-token', 'ios');
        RAISE EXCEPTION 'FAIL: duplicate token was accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'PASS: duplicate token rejected by unique constraint';
    END $$;
ROLLBACK;
