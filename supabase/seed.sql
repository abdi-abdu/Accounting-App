-- =============================================================================
-- seed.sql — Reference / lookup data
--
-- Safe to re-run at any time: every insert is idempotent (skips if the row
-- already exists by name). Run this after applying the baseline migration on
-- any fresh environment, and after every `supabase db reset` in local dev.
--
-- DO NOT add tenant-specific data here. This file is for platform-level
-- reference data only (subscription tiers, etc.).
-- =============================================================================

-- Subscription tiers (Module 2 §5.1 decisions).
-- Pricing values are placeholders — adjust in a new migration if they change
-- in production; never edit this seed file to track a price change.

insert into subscription_tiers (
  name,
  staff_account_limit,
  monthly_price,
  supports_custom_date_reports,
  supports_trend_charts,
  supports_export,
  is_active
)
select
  'Basic',
  1,        -- 1 staff account
  299.00,   -- ETB/month (placeholder)
  false,
  false,
  false,
  true
where not exists (
  select 1 from subscription_tiers where name = 'Basic'
);

insert into subscription_tiers (
  name,
  staff_account_limit,
  monthly_price,
  supports_custom_date_reports,
  supports_trend_charts,
  supports_export,
  is_active
)
select
  'Pro',
  null,     -- unlimited staff accounts
  799.00,   -- ETB/month (placeholder)
  true,
  true,
  true,
  true
where not exists (
  select 1 from subscription_tiers where name = 'Pro'
);
