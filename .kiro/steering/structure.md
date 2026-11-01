---
inclusion: always
---

# Project Structure and Rules

## Folder Layout

```
lib/
  main.dart                         # bootstrap only (Supabase init, ProviderScope)
  app.dart                          # MaterialApp.router (theme, locale, router)
  core/                             # cross-cutting infrastructure — no business logic
    auth/                           # AuthRepository + session state providers
    database/                       # AppDatabase (Drift), connection/, encryption/, tables/
    localization/                   # locale provider + appL10nProvider
    network/                        # supabaseClientProvider
    routing/                        # appRouterProvider (GoRouter)
    theme/                          # AppTheme
  features/
    <feature>/
      data/                         # concrete repository class + its provider
      domain/                       # plain entity classes and pure business rules only
      presentation/
        screens/                    # screen widgets
        providers/                  # screen-level controllers / notifiers
        widgets/                    # reusable widgets local to this feature
  shared_models/                    # entities used by 2+ features
  l10n/                             # generated AppLocalizations + .arb source files

supabase/
  migrations/                       # every DB change is a timestamped migration file
  functions/                        # Deno/TypeScript Edge Functions
  seed.sql                          # idempotent reference data (tiers)
  README.md
```

---

## 9 Non-Negotiable Rules (from .cursorrules — unchanged in meaning)

### Rule 1 — Stock is never a stored quantity
Current stock for an item is always `SUM(quantity_remaining)` across its `stock_batches` rows. Never add a `quantity` column to the `items` table or any equivalent shortcut.

### Rule 2 — FIFO costing only
When a sale consumes stock, always deplete the oldest unconsumed batch first. COGS for a sale line comes from the actual batch(es) consumed (`sale_item_batch_consumption`), never from an averaged or estimated cost.

### Rule 3 — Price override is one-way
`sale_items.unit_price` may differ from `items.master_selling_price` (a per-transaction override), but nothing ever writes an override back into the item's master price.

### Rule 4 — Staff must never see cost/COGS data
No query, view, or UI surface reachable by a `staff`-role user may expose `purchase_cost_per_unit`, `unit_cogs`, `total_cogs`, or anything profit/margin-derived. Use the `*_staff_view` views (baseline migration §11) for staff-facing reads — never the base tables.

### Rule 5 — Tenant isolation via `business_id`, enforced by RLS — not client code
Every operational table is scoped by `business_id`. Never rely on the Flutter app to filter tenant data "for safety" — assume a hostile client and require the database to enforce it. When adding a new table, always add `business_id` and a matching RLS policy in the same change.

Any view exposing tenant data must filter explicitly by `business_id = auth_business_id()`, use `security_barrier`, and revoke access from `anon`. Views run with their owner's privileges and bypass RLS unless created with `security_invoker`.

After any action that changes the user's `business_id` or role (e.g. business setup), call `supabase.auth.refreshSession()` so the JWT claims match the database. RLS policies read claims from the token — a stale token that predates the profile row will silently return zero rows from any RLS-gated table.

### Rule 6 — Subscription status is never client-writable
Only the Chapa webhook Edge Function (using the `service_role` key) may change `subscriptions.status` or insert `subscription_payments`. Never add a client-side path that marks a tenant as paid or active.

### Rule 7 — Offline-first, always
Every write in `features/*/data/*_repository.dart` must write to the local Drift database first and queue a sync operation — never make a write depend on a live network call succeeding.

### Rule 8 — Platform-conditional storage — don't merge the two backends
`core/database/connection/connection_native.dart` (mobile, SQLCipher encrypted) and `connection_web.dart` (web, WASM/OPFS, unencrypted — an accepted documented limitation) are selected via conditional import in `app_database.dart`. Don't add platform-specific logic anywhere else. Never use `kIsWeb` or `Platform.*` to branch database logic at runtime.

### Rule 9 — Domain logic lives in `domain/`, not in widgets or Supabase
FIFO calculation, price-override validation, and tier-limit checks are Dart functions in each feature's `domain/` folder — reusable, unit-testable, and identical whether online or offline.

---

## Localization Rules

- Every user-facing string goes in `lib/l10n/app_en.arb` first, then must also be added to `app_am.arb` (Amharic) and `app_om.arb` (Afaan Oromo) **in the same change** — never ship an English-only string and "translate later."
- Flag any new Amharic/Afaan Oromo translation as best-effort in a PR description if you are not a fluent speaker — do not present it as verified.
- Always use `appL10nProvider` (from `core/localization/app_l10n_provider.dart`). Never use `AppLocalizations.of(context)`.

---

## Multi-Tenant Rules

- Tiers: Basic (1 staff, standard reports) vs Pro (unlimited staff, custom date ranges, trend charts, PDF/Excel export). Check `subscription_tiers` feature flags — do not hardcode tier logic in the UI layer.
- Super Admin access to tenant data is consent-based and time-limited (`support_access_sessions`) — never build a standing or unrestricted Super Admin data-access path, even for convenience during debugging.

---

## Accepted Conventions (additions to the above rules)

### Convention 1 — `shared_models/` placement rule
`shared_models/` stays as a folder. A model goes there **only if 2 or more features use it**. If only one feature uses it, it lives in that feature's own `domain/` folder.

### Convention 2 — What `domain/` holds
`domain/` holds **plain entity classes and pure business rules only**. No use-case classes. No abstract repository interfaces. Repositories are concrete classes in `data/`.

### Convention 3 — Cross-feature import rule
A feature may import another feature's `domain/` entities and its repository provider only. It must never import another feature's `presentation/` or `data/` internals. The allowed dependency direction is:

```
sales → stock → items → categories
```

No cycles. If you think you need to break this, raise it before writing code.

### Convention 4 — Drift table location
All Drift table definitions live in `core/database/tables/` — not inside individual feature folders. `AppDatabase` in `core/database/app_database.dart` is the single assembly point that registers all tables.

### Convention 5 — Provider placement
- **Repository providers** sit next to the repository in `data/` (e.g. `itemRepositoryProvider` inside `item_repository.dart`).
- **Screen-level controllers and notifiers** go in `presentation/providers/`.
- No global providers folder. No provider files detached from what they expose.

### Convention 6 — Backend change rule
Every database change (tables, RLS policies, functions, triggers, grants) is a **new timestamped file** in `supabase/migrations/`. Never change the database only through the SQL Editor — if it isn't in a migration file, it doesn't exist as far as the repo is concerned.

### Convention 7 — Git is the developer's responsibility
Never run `git commit` or `git push`. The developer reviews the diff and commits manually.
