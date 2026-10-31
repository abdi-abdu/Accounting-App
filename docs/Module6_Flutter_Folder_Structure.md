# Module 6: Flutter Folder Structure
## Small Business Accounting & Inventory Management Platform (Multi-Tenant SaaS)

**Version:** 1.0 | **Date:** August 16, 2026
**Based on:** Module 5 Architecture (approved)

---

## 1. Organizing Principle: Feature-First, Layered Within Each Feature

Given the number of distinct domains (items, stock, sales, expenses, reports, subscription, staff, super admin), a **feature-first** structure is used — each feature owns its own presentation/domain/data slices — rather than one giant `screens/`, `models/`, `repositories/` split across the whole app. This keeps each domain's FIFO logic, RLS-aware queries, and UI together and easy to navigate, while a `core/` folder holds the genuinely shared infrastructure from Module 5 (local DB setup, sync manager, encryption, auth).

---

## 2. Full Folder Structure

```
lib/
│
├── main.dart                          # App entry point, ProviderScope, encrypted DB init
├── app.dart                           # MaterialApp, routing, role-aware navigation shell
│
├── core/                              # Shared infrastructure — used by every feature
│   ├── database/
│   │   ├── app_database.dart          # Drift database class, table definitions
│   │   ├── encryption/
│   │   │   └── db_encryption_service.dart   # sqlcipher key generation via flutter_secure_storage
│   │   └── tables/                    # One Drift table file per Module 4 table
│   │       ├── businesses_table.dart
│   │       ├── profiles_table.dart
│   │       ├── items_table.dart
│   │       ├── stock_batches_table.dart
│   │       ├── sales_table.dart
│   │       ├── sale_items_table.dart
│   │       ├── batch_consumption_table.dart
│   │       ├── expenses_table.dart
│   │       └── pending_sync_operations_table.dart
│   │
│   ├── sync/
│   │   ├── sync_manager.dart          # Drains pending_sync_operations when online (Module 5, §3.1)
│   │   ├── connectivity_watcher.dart  # Wraps connectivity_plus
│   │   └── reconciliation_handler.dart # Surfaces FR-11.5 alerts from Supabase to local state
│   │
│   ├── auth/
│   │   ├── auth_repository.dart       # Supabase Auth wrapper; reads role/business_id JWT claims
│   │   └── session_state.dart
│   │
│   ├── subscription/
│   │   ├── subscription_repository.dart   # Reads tier/status; mirrors server-side gating locally
│   │   └── tier_limits.dart               # Basic/Pro feature-flag constants (Module 2, §5.1)
│   │
│   ├── network/
│   │   └── supabase_client_provider.dart
│   │
│   ├── theme/
│   │   └── app_theme.dart
│   │
│   ├── routing/
│   │   ├── app_router.dart            # go_router config
│   │   └── role_guard.dart            # Redirects based on role (Owner/Staff/Super Admin) — UX layer only, not the real enforcement (that's RLS)
│   │
│   └── widgets/                       # Genuinely generic shared widgets (buttons, loaders, sync status badge)
│       └── sync_status_badge.dart
│
├── features/
│   │
│   ├── onboarding/                    # UC-01: Sign Up as New Tenant
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       └── screens/
│   │           └── signup_screen.dart
│   │
│   ├── dashboard/                     # UC-09
│   │   ├── domain/
│   │   │   └── dashboard_stats_calculator.dart   # Role-aware: Owner vs Staff figures
│   │   └── presentation/
│   │       ├── screens/dashboard_screen.dart
│   │       └── widgets/               # stat cards, low-stock banner, recent sales list
│   │
│   ├── categories/                    # UC-04
│   │   ├── data/category_repository.dart
│   │   ├── domain/category.dart
│   │   └── presentation/
│   │
│   ├── items/                         # UC-05
│   │   ├── data/item_repository.dart
│   │   ├── domain/
│   │   │   ├── item.dart
│   │   │   └── item_validation_rules.dart     # Owner-only price edit rule, enforced client-side too
│   │   └── presentation/
│   │
│   ├── stock/                         # UC-06
│   │   ├── data/stock_repository.dart
│   │   ├── domain/
│   │   │   ├── stock_batch.dart
│   │   │   └── fifo_calculator.dart           # THE core domain logic: batch consumption order (Module 5, §2.3)
│   │   └── presentation/
│   │       └── widgets/low_stock_indicator.dart   # UC-12
│   │
│   ├── sales/                         # UC-07
│   │   ├── data/sales_repository.dart
│   │   ├── domain/
│   │   │   ├── sale.dart
│   │   │   ├── sale_item.dart
│   │   │   └── price_override_rules.dart      # One-way price flow enforcement (Module 4, §4)
│   │   └── presentation/
│   │       └── screens/record_sale_screen.dart
│   │
│   ├── expenses/                      # UC-08
│   │   ├── data/expense_repository.dart
│   │   ├── domain/expense.dart
│   │   └── presentation/
│   │
│   ├── reports/                       # UC-10, UC-11
│   │   ├── domain/
│   │   │   ├── report_calculator.dart         # Daily/weekly/monthly + custom range (Pro)
│   │   │   └── trend_analytics_calculator.dart # Pro-only (FR-8.6)
│   │   ├── data/report_export_service.dart    # PDF/Excel generation (Pro, FR-8.3)
│   │   └── presentation/
│   │       ├── screens/reports_screen.dart
│   │       └── widgets/sales_trend_chart.dart
│   │
│   ├── staff_management/              # UC-03
│   │   ├── data/staff_repository.dart
│   │   ├── domain/staff_limit_checker.dart    # Basic=1 / Pro=unlimited enforcement (client-side mirror)
│   │   └── presentation/
│   │
│   ├── billing/                       # UC-13, UC-14, UC-15
│   │   ├── data/
│   │   │   ├── chapa_payment_service.dart     # Initiates Chapa checkout flow
│   │   │   └── subscription_status_repository.dart
│   │   └── presentation/
│   │       ├── screens/subscription_screen.dart
│   │       └── widgets/grace_period_banner.dart
│   │
│   └── super_admin/                   # UC-16, UC-17, UC-18, UC-21
│       ├── data/
│       │   ├── tenant_management_repository.dart
│       │   ├── subscription_plan_repository.dart
│       │   └── support_access_repository.dart     # Time-limited consented access (Module 4, §5)
│       └── presentation/
│           ├── screens/
│           │   ├── tenant_list_screen.dart
│           │   ├── plan_management_screen.dart
│           │   └── platform_health_screen.dart
│           └── widgets/
│
├── shared_models/                     # Cross-feature models that don't belong to one domain
│   └── user_role.dart                 # enum: superAdmin, owner, staff
│
└── l10n/                              # Reserved for future localization (out of scope now, but cheap to reserve)
```

---

## 3. Why Certain Things Live Where They Do

- **`fifo_calculator.dart` lives in `features/stock/domain/`, not `core/`** — even though it's critically important, it's specific to the stock domain's business rules, not generic infrastructure. `core/` is reserved for things every feature needs (database, sync, auth), not shared business logic.
- **`price_override_rules.dart` lives in `features/sales/domain/`** — enforcing the one-way price flow client-side gives instant UI feedback, but remember: the *real* enforcement is the RLS policy from Module 4. This file exists for UX, not security.
- **`tier_limits.dart` in `core/subscription/`** — used across multiple features (staff_management, reports, billing all need to know current tier), so it's shared infrastructure, not one feature's concern.
- **`super_admin/` is a fully separate feature module**, not scattered across other features — since Super Admin is a distinct role with almost no UI overlap with Owner/Staff screens (Module 3 permission matrix), keeping it isolated avoids accidentally coupling tenant-facing and platform-facing code.
- **Each feature has its own `data/domain/presentation` split** (not `data/` and `presentation/` shared globally) so a feature can be understood, tested, or even removed as a self-contained unit — useful given this app will keep growing (Section 1.4 deferred features will each become a new feature folder later, e.g. `features/suppliers/`, `features/customers/`, `features/barcode/`).

---

## 4. Naming & Convention Notes

- Riverpod providers are colocated with the repository/domain file they expose (e.g., `item_repository.dart` also defines `itemRepositoryProvider`), rather than a separate global `providers/` folder — keeps related code together per feature-first principle.
- Drift table files in `core/database/tables/` map 1:1 to Module 4 tables — a developer can always find the schema definition for any table by name.
- Test folders (`test/`) will mirror this exact structure once we reach implementation, so `test/features/stock/domain/fifo_calculator_test.dart` tests `lib/features/stock/domain/fifo_calculator.dart` — not detailed further here since it's outside Module 6's scope, but worth noting the structure was chosen partly for this mirroring.

---

*End of Module 6. Pending your review before proceeding to Module 7: Supabase Schema (actual SQL).*
