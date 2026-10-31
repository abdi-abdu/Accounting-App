-- =============================================================================
-- Migration: 20261031000000_staff_views_tenant_filter.sql
--
-- The original staff views (baseline §12) ran with the view owner's privileges
-- and had no tenant filter. Because views run with their owner's privileges
-- by default (not the caller's), the base-table RLS policies were bypassed
-- entirely, and a staff user from one tenant could read another tenant's rows.
-- These replacements add security_barrier and filter explicitly by the caller's
-- business_id via auth_business_id(), so the tenant boundary is enforced at
-- the view level regardless of how the view owner's privileges are resolved.
-- Access is also revoked from anon — staff views are for authenticated users only.
-- =============================================================================

create or replace view public.stock_batches_staff_view
  with (security_barrier = true) as
  select id, business_id, item_id, quantity_received, quantity_remaining,
         received_at, created_by
  from public.stock_batches
  where business_id = public.auth_business_id();

create or replace view public.sales_staff_view
  with (security_barrier = true) as
  select id, business_id, sold_by, sale_date, payment_method, device_id, created_at
  from public.sales
  where business_id = public.auth_business_id();

create or replace view public.sale_items_staff_view
  with (security_barrier = true) as
  select id, business_id, sale_id, item_id, quantity, unit_price
  from public.sale_items
  where business_id = public.auth_business_id();

revoke all on public.stock_batches_staff_view from anon;
revoke all on public.sales_staff_view         from anon;
revoke all on public.sale_items_staff_view    from anon;
