-- =============================================================================
-- BASELINE MIGRATION — 00000000000000_baseline.sql
--
-- This is a snapshot of the schema already deployed to the live project as of
-- Phase 1 completion. DO NOT run this against the live project — it will fail
-- on every CREATE because all objects already exist.
--
-- This file exists for TWO purposes only:
--   1. Spinning up a brand-new environment (local dev, staging, CI) from scratch.
--   2. Serving as the authoritative written record of the starting state from
--      which all future numbered migrations apply.
--
-- All future changes go in a NEW file: supabase/migrations/<timestamp>_<description>.sql
-- Never edit this file once it has been applied anywhere.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. EXTENSIONS
-- -----------------------------------------------------------------------------

create extension if not exists "pgcrypto"; -- gen_random_uuid()


-- -----------------------------------------------------------------------------
-- 1. ENUM TYPES
-- -----------------------------------------------------------------------------

create type user_role as enum ('super_admin', 'owner', 'staff');
create type subscription_status as enum ('trial', 'active', 'grace_period', 'restricted');
create type payment_method_type as enum ('telebirr', 'cbe_birr', 'bank_transfer');
create type payment_status_type as enum ('pending', 'confirmed', 'failed');
create type alert_status_type as enum ('open', 'resolved');
create type sale_payment_method as enum ('cash'); -- extensible later per FR-5.4


-- -----------------------------------------------------------------------------
-- 2. CORE TENANT & USER TABLES
-- -----------------------------------------------------------------------------

create table businesses (
  id              uuid        primary key default gen_random_uuid(),
  name            text        not null,
  owner_user_id   uuid        not null references auth.users(id),
  currency_code   text        not null default 'ETB',
  is_active       boolean     not null default true,
  created_at      timestamptz not null default now()
);

create table profiles (
  id          uuid        primary key references auth.users(id) on delete cascade,
  business_id uuid        references businesses(id), -- nullable for super_admin only
  role        user_role   not null,
  full_name   text        not null,
  is_active   boolean     not null default true,
  created_at  timestamptz not null default now()
);
create index idx_profiles_business_id on profiles(business_id);


-- -----------------------------------------------------------------------------
-- 3. SUBSCRIPTION & BILLING TABLES
-- -----------------------------------------------------------------------------

create table subscription_tiers (
  id                           uuid         primary key default gen_random_uuid(),
  name                         text         not null,            -- 'Basic', 'Pro'
  staff_account_limit          integer,                          -- null = unlimited
  monthly_price                numeric(12,2) not null,
  supports_custom_date_reports boolean      not null default false,
  supports_trend_charts        boolean      not null default false,
  supports_export              boolean      not null default false,
  is_active                    boolean      not null default true
);

create table subscriptions (
  id                   uuid                primary key default gen_random_uuid(),
  business_id          uuid                not null unique references businesses(id),
  tier_id              uuid                not null references subscription_tiers(id),
  status               subscription_status not null default 'trial',
  trial_ends_at        timestamptz,
  current_period_end   timestamptz,
  grace_period_ends_at timestamptz,
  updated_at           timestamptz         not null default now()
);
create index idx_subscriptions_business_id on subscriptions(business_id);

create table subscription_payments (
  id               uuid                 primary key default gen_random_uuid(),
  business_id      uuid                 not null references businesses(id),
  tier_id          uuid                 not null references subscription_tiers(id),
  amount           numeric(12,2)        not null,
  payment_method   payment_method_type  not null,
  chapa_reference  text,
  status           payment_status_type  not null default 'pending',
  paid_at          timestamptz,
  created_at       timestamptz          not null default now()
);
create index idx_subscription_payments_business_id on subscription_payments(business_id);


-- -----------------------------------------------------------------------------
-- 4. CATALOG TABLES
-- -----------------------------------------------------------------------------

create table categories (
  id          uuid    primary key default gen_random_uuid(),
  business_id uuid    not null references businesses(id),
  name        text    not null,
  is_active   boolean not null default true
);
create index idx_categories_business_id on categories(business_id);

create table items (
  id                   uuid          primary key default gen_random_uuid(),
  business_id          uuid          not null references businesses(id),
  category_id          uuid          not null references categories(id),
  name                 text          not null,
  unit_of_measure      text          not null,
  master_selling_price numeric(12,2) not null,
  reorder_threshold    numeric(12,2) not null default 0,
  barcode              text,         -- reserved, inactive in v1
  image_url            text,
  is_active            boolean       not null default true,
  created_at           timestamptz   not null default now()
);
create index idx_items_business_id  on items(business_id);
create index idx_items_category_id  on items(category_id);


-- -----------------------------------------------------------------------------
-- 5. STOCK LEDGER (FIFO CORE)
-- -----------------------------------------------------------------------------

create table stock_batches (
  id                    uuid          primary key default gen_random_uuid(),
  business_id           uuid          not null references businesses(id),
  item_id               uuid          not null references items(id),
  quantity_received     numeric(14,3) not null check (quantity_received > 0),
  quantity_remaining    numeric(14,3) not null check (quantity_remaining >= 0),
  purchase_cost_per_unit numeric(12,2) not null,
  received_at           timestamptz   not null default now(),
  created_by            uuid          not null references profiles(id)
);
create index idx_stock_batches_business_id  on stock_batches(business_id);
create index idx_stock_batches_item_fifo    on stock_batches(item_id, received_at); -- drives FIFO ordering


-- -----------------------------------------------------------------------------
-- 6. SALES TABLES
-- -----------------------------------------------------------------------------

create table sales (
  id             uuid                primary key default gen_random_uuid(),
  business_id    uuid                not null references businesses(id),
  sold_by        uuid                not null references profiles(id),
  sale_date      timestamptz         not null default now(),
  payment_method sale_payment_method not null default 'cash',
  total_revenue  numeric(14,2)       not null,
  total_cogs     numeric(14,2)       not null,
  device_id      text                not null, -- FR-11.5 reconciliation
  created_at     timestamptz         not null default now()
);
create index idx_sales_business_id on sales(business_id, sale_date);

create table sale_items (
  id          uuid          primary key default gen_random_uuid(),
  business_id uuid          not null references businesses(id), -- denormalized for simpler RLS
  sale_id     uuid          not null references sales(id) on delete cascade,
  item_id     uuid          not null references items(id),
  quantity    numeric(14,3) not null check (quantity > 0),
  unit_price  numeric(12,2) not null, -- FR-5.2: independent of items.master_selling_price
  unit_cogs   numeric(12,2) not null  -- weighted cost across consumed batches
);
create index idx_sale_items_business_id on sale_items(business_id);
create index idx_sale_items_sale_id     on sale_items(sale_id);

create table sale_item_batch_consumption (
  id                      uuid          primary key default gen_random_uuid(),
  sale_item_id            uuid          not null references sale_items(id) on delete cascade,
  stock_batch_id          uuid          not null references stock_batches(id),
  quantity_consumed       numeric(14,3) not null check (quantity_consumed > 0),
  cost_per_unit_snapshot  numeric(12,2) not null
);
create index idx_batch_consumption_sale_item on sale_item_batch_consumption(sale_item_id);
create index idx_batch_consumption_batch     on sale_item_batch_consumption(stock_batch_id);


-- -----------------------------------------------------------------------------
-- 7. EXPENSE TABLES
-- -----------------------------------------------------------------------------

create table expense_categories (
  id          uuid    primary key default gen_random_uuid(),
  business_id uuid    not null references businesses(id),
  name        text    not null,
  is_active   boolean not null default true
);
create index idx_expense_categories_business_id on expense_categories(business_id);

create table expenses (
  id           uuid          primary key default gen_random_uuid(),
  business_id  uuid          not null references businesses(id),
  category_id  uuid          not null references expense_categories(id),
  amount       numeric(12,2) not null,
  expense_date timestamptz   not null default now(),
  note         text,
  recorded_by  uuid          not null references profiles(id)
);
create index idx_expenses_business_id on expenses(business_id, expense_date);


-- -----------------------------------------------------------------------------
-- 8. RECONCILIATION & SUPPORT ACCESS
-- -----------------------------------------------------------------------------

create table reconciliation_alerts (
  id               uuid             primary key default gen_random_uuid(),
  business_id      uuid             not null references businesses(id),
  item_id          uuid             not null references items(id),
  description      text             not null,
  related_sale_ids uuid[]           not null default '{}',
  status           alert_status_type not null default 'open',
  created_at       timestamptz      not null default now()
);
create index idx_reconciliation_alerts_business_id on reconciliation_alerts(business_id);

create table support_access_sessions (
  id             uuid        primary key default gen_random_uuid(),
  business_id    uuid        not null references businesses(id),
  granted_by     uuid        not null references profiles(id), -- the Owner
  super_admin_id uuid        not null references profiles(id), -- the Super Admin granted access
  reason         text        not null,
  granted_at     timestamptz not null default now(),
  expires_at     timestamptz not null,
  revoked_at     timestamptz
);
create index idx_support_access_business_id on support_access_sessions(business_id);


-- -----------------------------------------------------------------------------
-- 9. HELPER FUNCTIONS (must exist before RLS policies that call them)
-- -----------------------------------------------------------------------------

-- auth_role() reads the app_role claim (NOT the reserved 'role' claim).
-- 'role' is used internally by Supabase for Postgres role switching —
-- using it as a custom claim causes silent JWT conflicts. Our app-level
-- role travels under 'app_role', set by custom_access_token_hook below.
create or replace function auth_role() returns text as $$
  select auth.jwt() ->> 'app_role';
$$ language sql stable;

create or replace function auth_business_id() returns uuid as $$
  select (auth.jwt() ->> 'business_id')::uuid;
$$ language sql stable;


-- -----------------------------------------------------------------------------
-- 10. JWT CUSTOM CLAIMS — Auth Hook
--
-- Registered in the Supabase dashboard as a "Custom Access Token" hook.
-- Injects app_role and business_id into every JWT so RLS policies can
-- read them via auth.jwt() without a profiles table lookup on every query.
--
-- IMPORTANT: the claim key is 'app_role', NOT 'role'. 'role' is reserved
-- by Supabase for internal Postgres role switching; overwriting it breaks
-- the connection. This is the corrected version — the original §9 in the
-- source SQL used 'role' and was superseded by §16 of the same file.
-- -----------------------------------------------------------------------------

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  claims       jsonb;
  user_profile record;
begin
  select role, business_id
  into   user_profile
  from   public.profiles
  where  id = (event->>'user_id')::uuid;

  claims := event->'claims';

  if user_profile is not null then
    claims := jsonb_set(claims, '{app_role}',    to_jsonb(user_profile.role));
    claims := jsonb_set(claims, '{business_id}', to_jsonb(user_profile.business_id));
  end if;

  event := jsonb_set(event, '{claims}', claims);
  return event;
end;
$$;


-- -----------------------------------------------------------------------------
-- 11. ROW LEVEL SECURITY
-- -----------------------------------------------------------------------------

alter table businesses                  enable row level security;
alter table profiles                    enable row level security;
alter table subscriptions               enable row level security;
alter table subscription_payments       enable row level security;
alter table categories                  enable row level security;
alter table items                       enable row level security;
alter table stock_batches               enable row level security;
alter table sales                       enable row level security;
alter table sale_items                  enable row level security;
alter table sale_item_batch_consumption enable row level security;
alter table expense_categories          enable row level security;
alter table expenses                    enable row level security;
alter table reconciliation_alerts       enable row level security;
alter table support_access_sessions     enable row level security;

-- businesses: owner sees own; super_admin sees all (read-only for support)
create policy "owner reads own business" on businesses
  for select using (id = auth_business_id() or auth_role() = 'super_admin');
create policy "owner updates own business" on businesses
  for update using (id = auth_business_id() and auth_role() = 'owner');

-- profiles: tenant-scoped; only owner can insert/update staff profiles
create policy "read profiles in own tenant" on profiles
  for select using (business_id = auth_business_id() or auth_role() = 'super_admin');
create policy "owner manages staff profiles" on profiles
  for insert with check (business_id = auth_business_id() and auth_role() = 'owner');
create policy "owner updates staff profiles" on profiles
  for update using (business_id = auth_business_id() and auth_role() = 'owner');

-- categories: owner full access, staff read-only
create policy "tenant reads categories" on categories
  for select using (business_id = auth_business_id());
create policy "owner writes categories" on categories
  for insert with check (business_id = auth_business_id() and auth_role() = 'owner');
create policy "owner updates categories" on categories
  for update using (business_id = auth_business_id() and auth_role() = 'owner');

-- items: owner full access (incl. master_selling_price), staff read-only
create policy "tenant reads items" on items
  for select using (business_id = auth_business_id());
create policy "owner writes items" on items
  for insert with check (business_id = auth_business_id() and auth_role() = 'owner');
create policy "owner updates items" on items
  for update using (business_id = auth_business_id() and auth_role() = 'owner');

-- stock_batches: base table SELECT restricted to owner (contains purchase_cost_per_unit).
-- Staff read stock via stock_batches_staff_view (§12), not this table.
create policy "owner reads stock batches" on stock_batches
  for select using (business_id = auth_business_id() and auth_role() = 'owner');
create policy "owner or staff insert stock batches" on stock_batches
  for insert with check (business_id = auth_business_id() and auth_role() in ('owner', 'staff'));

-- sales: owner reads full detail (incl. COGS); staff read via sales_staff_view (§12)
create policy "owner reads sales" on sales
  for select using (business_id = auth_business_id() and auth_role() = 'owner');
create policy "owner or staff insert sales" on sales
  for insert with check (business_id = auth_business_id() and auth_role() in ('owner', 'staff'));

create policy "owner reads sale_items" on sale_items
  for select using (business_id = auth_business_id() and auth_role() = 'owner');
create policy "owner or staff insert sale_items" on sale_items
  for insert with check (business_id = auth_business_id() and auth_role() in ('owner', 'staff'));

-- batch consumption inherits sensitivity from stock_batches/sale_items — owner only
create policy "owner reads batch consumption" on sale_item_batch_consumption
  for select using (
    exists (
      select 1 from sale_items si
      where si.id = sale_item_id
        and si.business_id = auth_business_id()
        and auth_role() = 'owner'
    )
  );
create policy "owner or staff insert batch consumption" on sale_item_batch_consumption
  for insert with check (
    exists (
      select 1 from sale_items si
      where si.id = sale_item_id
        and si.business_id = auth_business_id()
        and auth_role() in ('owner', 'staff')
    )
  );

-- expense_categories: owner manages, staff read for selection purposes
create policy "tenant reads expense categories" on expense_categories
  for select using (business_id = auth_business_id());
create policy "owner writes expense categories" on expense_categories
  for insert with check (business_id = auth_business_id() and auth_role() = 'owner');

-- expenses: staff can INSERT (record) but not SELECT (FR-6.4) — owner does both
create policy "owner reads expenses" on expenses
  for select using (business_id = auth_business_id() and auth_role() = 'owner');
create policy "owner or staff insert expenses" on expenses
  for insert with check (business_id = auth_business_id() and auth_role() in ('owner', 'staff'));

-- reconciliation_alerts: owner only (Module 3 permission matrix)
create policy "owner reads reconciliation alerts" on reconciliation_alerts
  for select using (business_id = auth_business_id() and auth_role() = 'owner');

-- support_access_sessions: owner grants/revokes; super_admin reads own granted sessions
create policy "owner manages support access" on support_access_sessions
  for all using (business_id = auth_business_id() and auth_role() = 'owner');
create policy "super_admin reads own granted sessions" on support_access_sessions
  for select using (super_admin_id = auth.uid() and auth_role() = 'super_admin');

-- subscriptions & payments: owner reads own; only Edge Functions (service_role) write.
-- No insert/update policies for owner — these are written exclusively by the
-- Chapa webhook Edge Function using the service_role key, which bypasses RLS.
create policy "owner reads own subscription" on subscriptions
  for select using (business_id = auth_business_id());
create policy "owner reads own payments" on subscription_payments
  for select using (business_id = auth_business_id());


-- -----------------------------------------------------------------------------
-- 12. COLUMN-LEVEL SECURITY: STAFF-SAFE VIEWS
--
-- Staff must never see purchase_cost_per_unit, unit_cogs, or total_cogs.
-- The Flutter app queries these views (not base tables) when app_role = 'staff'.
-- -----------------------------------------------------------------------------

create view stock_batches_staff_view as
  select id, business_id, item_id, quantity_received, quantity_remaining,
         received_at, created_by
  from stock_batches;
-- purchase_cost_per_unit intentionally omitted

create view sales_staff_view as
  select id, business_id, sold_by, sale_date, payment_method, device_id, created_at
  from sales;
-- total_revenue and total_cogs intentionally omitted

create view sale_items_staff_view as
  select id, business_id, sale_id, item_id, quantity, unit_price
  from sale_items;
-- unit_cogs intentionally omitted

alter view stock_batches_staff_view owner to postgres;
alter view sales_staff_view         owner to postgres;
alter view sale_items_staff_view     owner to postgres;

grant select on stock_batches_staff_view to authenticated;
grant select on sales_staff_view         to authenticated;
grant select on sale_items_staff_view    to authenticated;


-- -----------------------------------------------------------------------------
-- 13. RECONCILIATION TRIGGER (FR-11.5)
--
-- Fires before a stock_batch update. If quantity_remaining would go negative
-- (e.g. after multi-device sync merges overlapping offline sales), it clamps
-- to zero and inserts a reconciliation_alert rather than allowing a silent
-- negative value.
-- -----------------------------------------------------------------------------

create or replace function detect_stock_oversell()
returns trigger as $$
begin
  if new.quantity_remaining < 0 then
    insert into reconciliation_alerts (business_id, item_id, description, related_sale_ids)
    values (
      new.business_id,
      new.item_id,
      format('Stock batch oversold by %s units after multi-device sync', abs(new.quantity_remaining)),
      '{}'
    );
    new.quantity_remaining := 0; -- clamp so downstream stock sums never go negative
  end if;
  return new;
end;
$$ language plpgsql;

create trigger trg_detect_stock_oversell
  before update on stock_batches
  for each row
  execute function detect_stock_oversell();


-- -----------------------------------------------------------------------------
-- 14. UPDATED_AT TRIGGER
-- -----------------------------------------------------------------------------

create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_subscriptions_updated_at
  before update on subscriptions
  for each row execute function set_updated_at();


-- -----------------------------------------------------------------------------
-- 15. UC-01 BUSINESS SIGNUP FUNCTION
--
-- Called by the Flutter app (BusinessSetupRepository) once the user has
-- confirmed their email and logged in but has no profiles row yet.
-- Atomically creates the business, owner profile, and 30-day trial
-- subscription — all scoped to auth.uid() server-side, so a client can
-- never create a business on someone else's behalf.
--
-- SECURITY DEFINER so it can insert into businesses/profiles/subscriptions
-- without the calling user having direct INSERT permission on those tables.
-- search_path is pinned to public to prevent search_path injection.
-- -----------------------------------------------------------------------------

create or replace function public.handle_new_business_signup(
  business_name   text,
  owner_full_name text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  new_business_id uuid;
  basic_tier_id   uuid;
begin
  if exists (select 1 from profiles where id = auth.uid()) then
    raise exception 'A business is already set up for this account';
  end if;

  select id into basic_tier_id
  from   subscription_tiers
  where  name = 'Basic'
  limit  1;

  if basic_tier_id is null then
    raise exception 'Basic tier not configured — run seed.sql first';
  end if;

  insert into businesses (name, owner_user_id)
  values (business_name, auth.uid())
  returning id into new_business_id;

  insert into profiles (id, business_id, role, full_name)
  values (auth.uid(), new_business_id, 'owner', owner_full_name);

  insert into subscriptions (business_id, tier_id, status, trial_ends_at)
  values (new_business_id, basic_tier_id, 'trial', now() + interval '30 days');

  return new_business_id::text;
end;
$$;

grant execute on function public.handle_new_business_signup(text, text) to authenticated;


-- -----------------------------------------------------------------------------
-- 16. AUTH HOOK GRANTS
--
-- supabase_auth_admin has no permissions on the public schema by default.
-- These grants are required for custom_access_token_hook to execute when
-- Supabase calls it during token minting.
-- -----------------------------------------------------------------------------

grant usage   on schema public                                     to supabase_auth_admin;
grant execute on function public.custom_access_token_hook          to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook         from authenticated, anon, public;
grant select  on public.profiles                                   to supabase_auth_admin;

create policy "Allow auth admin to read profiles" on public.profiles
  as permissive
  for select
  to supabase_auth_admin
  using (true);

-- =============================================================================
-- End of baseline.
-- Tier seed data (Basic / Pro rows) is in supabase/seed.sql, not here,
-- so it can be re-run idempotently without re-running the full schema.
-- =============================================================================
