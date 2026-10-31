---
inclusion: always
---

# Product: SBA App

## What It Is

SBA App is a **multi-tenant SaaS accounting and inventory management application** for Ethiopian small businesses (shops, micro-retailers, service businesses). It is sold as a subscription product; each subscribing business is one isolated tenant.

## Target Users and Roles

Every decision about what a screen shows, what data it queries, and what actions it allows must account for all three roles:

| Role | Description |
|---|---|
| **Owner** | The business owner. Full access to their own tenant: inventory, sales, expenses, staff, reports, billing. Cannot see any other tenant's data. |
| **Staff** | An employee added by the Owner. Restricted access: can record sales and view stock, but cannot see financial reports, manage staff, change billing, or view any cost or COGS data. Exact permission set is defined per feature as it is built — always refer to Module 3 permission matrix. |
| **Super Admin** | Platform operator. Cross-tenant visibility for support and subscription management only. Never appears in a tenant's own staff list. Super Admin access to any tenant's operational data is consent-based and time-limited via `support_access_sessions` — never build a standing or unrestricted Super Admin data-access path. |

## Billing and Payments

Subscriptions are managed in-app. Payment processing uses **Chapa** (Ethiopian payment gateway — not Stripe, not any other provider). Subscription tiers:

- **Basic**: 1 staff account, standard reports, 299 ETB/month
- **Pro**: unlimited staff, custom date reports, trend charts, PDF/Excel export, 799 ETB/month

Trial period is 30 days, created automatically at business signup. Subscription lifecycle: `trial` → `active` → `grace_period` (3 days) → `restricted`. Subscription status is **never client-writable** — only the Chapa webhook Edge Function (service_role key) may change it.

## Languages

The app supports three languages. All three are first-class — never ship an English-only string and translate later:

- **English** (`en`) — default fallback
- **Amharic** (`am`) — Ge'ez script; requires NotoSansEthiopic font
- **Afaan Oromo** (`om`) — Latin script; NOT in Flutter's MaterialLocalizations, handled via app-level workaround (see tech.md)

Language preference is stored locally (SharedPreferences), never synced to the cloud.

## Platform Strategy

- **Web first**: the primary delivery target is Flutter web.
- **Mobile later**: Android and iOS are planned but not the current build target. Any mobile-specific code (SQLCipher, platform channels) must be conditionally compiled and clearly marked.

## Product Phases

| Phase | Scope |
|---|---|
| 0 | Infrastructure: Supabase auth, Drift DB stub, theming, localization |
| 1 | Onboarding: sign-up, email confirm, business setup, role-based routing |
| 2 | Categories + Items (inventory core) |
| 3 | Stock management (batches, adjustments) |
| 4 | Sales recording |
| 5 | Dashboard + reports |
| 6 | Expenses |
| 7 | Staff management |
| 8 | Billing and subscription UI |
| 9 | Super Admin portal |
| 10 | Offline sync and mobile hardening |

Before implementing any feature, check `/docs/Module3_UserRoles_UseCases.md` for the use-case and permission matrix, `/docs/Module4_Database_Design.md` for the tables involved, and `/docs/Implementation_Roadmap.md` for phase dependencies.
