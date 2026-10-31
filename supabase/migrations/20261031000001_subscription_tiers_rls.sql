-- =============================================================================
-- Migration: 20261031000001_subscription_tiers_rls.sql
--
-- The live database already had RLS enabled on subscription_tiers and the
-- baseline migration omitted it. This adds a read-only policy so signed-in
-- users can see active tiers (needed by handle_new_business_signup and by
-- the billing UI to display available plans).
-- =============================================================================

alter table public.subscription_tiers enable row level security;

drop policy if exists "authenticated read active tiers" on public.subscription_tiers;

create policy "authenticated read active tiers"
  on public.subscription_tiers
  for select
  to authenticated
  using (is_active = true);
