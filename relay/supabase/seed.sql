-- MarkPush Seed Data
-- Populate the beta whitelist for local development and staging environments.
-- DO NOT run this against production; use the admin dashboard instead.

insert into public.beta_whitelist (email, invited_by)
values
    ('rahilsinghi300@gmail.com', 'system')
on conflict (email) do nothing;
