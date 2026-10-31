# Implementation Roadmap
## Small Business Accounting & Inventory Management Platform

**Based on:** Modules 1–7 (all approved)
**This document:** sequences the actual build. Phase 0 (this session) covers environment setup only, per your instruction — no business modules yet.

---

## Phase 0 — Development Environment Setup *(this session)*
- Flutter project created, matching Module 6 folder structure
- Core infrastructure wired: Supabase client, Riverpod `ProviderScope`, Go Router, encrypted local database connection
- Supabase project provisioned and Module 7 schema deployed
- A minimal splash → login → home flow proving the wiring works end-to-end (not a real feature — a "proof of life" screen, replaced in Phase 2)
- **Exit criteria:** `flutter run` launches the app, a test user can log in against your real Supabase project, and the encrypted local database file is created on-device.

## Phase 1 — Auth, Tenant Bootstrap & Onboarding (UC-01, UC-02)
- Real sign-up flow (creates `businesses` + `profiles` row, starts 30-day trial)
- Login/logout, session persistence, role/business_id resolution from JWT claims
- Role-aware routing (Owner/Staff/Super Admin land on different home screens)
- **Exit criteria:** a new business owner can sign up, land on an empty dashboard, and staff cannot be created yet (Phase 3) but the Owner shell exists.

## Phase 2 — Catalog & Stock (UC-04, UC-05, UC-06)
- Categories and Items CRUD (Owner-only writes, per RLS)
- Stock batch entry (`stock_batches`), with the FIFO calculator built and **unit-tested in isolation** before it's wired to sales (this logic is too important to debug live)
- Low stock indicator (UC-12) — visual only, since no sales exist yet to deplete stock

## Phase 3 — Sales Recording (UC-07)
- Sale entry flow: cart, price override, payment confirmation
- FIFO batch consumption wired end-to-end (`sale_items` + `sale_item_batch_consumption`)
- Stock-to-zero warning / negative-stock block (FR-4.5)
- **This is the highest-risk phase** — recommend the most thorough manual + automated testing here, since FIFO costing errors silently corrupt every downstream profit number.

## Phase 4 — Staff Accounts & Permissions (UC-03)
- Staff account creation with tier-limit enforcement (Basic=1, Pro=unlimited)
- Staff-safe views wired into the repository layer (role-based query switching)
- Manual verification: log in as Staff, confirm cost/COGS fields are genuinely inaccessible (not just hidden in UI)

## Phase 5 — Expenses & Reporting (UC-08, UC-09, UC-10, UC-11)
- Expense entry (Staff write-only, Owner read+write)
- Dashboard (role-aware figures)
- Daily/Weekly/Monthly reports; Pro-tier custom range + trend charts; PDF/Excel export

## Phase 6 — Offline Sync Hardening (UC-19, UC-20)
- Full sync queue + background drain implementation
- Reconciliation alert surfacing in the Owner UI (the DB trigger from Module 7 already detects it — this phase builds the UI/notification for it)
- Deliberate offline-mode testing: airplane mode during a sale, force-close mid-write, multi-device conflict simulation

## Phase 7 — Subscription & Billing (UC-13, UC-14, UC-15)
- Chapa checkout integration from the Flutter side
- Trial countdown banner, grace period banner, restricted-mode write-blocking
- Deploy the two Edge Functions from Module 7's companion doc (webhook + scheduled status checker)

## Phase 8 — Super Admin Portal (UC-16, UC-17, UC-18, UC-21)
- Tenant list, plan management, platform health dashboard
- Consent-based support access flow (both sides: Owner grants, Super Admin sessions)
- **Note:** this could arguably be built as early as Phase 1 if you need to manually manage early customers before self-serve billing (Phase 7) is ready — flagging this as a possible reordering depending on how you plan to onboard your first real tenants.

## Phase 9 — Polish, Testing, Launch Prep
- Full regression pass against the Module 3 use case catalog (all 21 use cases)
- Security review: manually attempt to bypass RLS as a Staff account (e.g., direct API calls) to confirm server-side enforcement, not just UI hiding
- App store listing assets, privacy policy (required given financial data handling)

---

## A Note on Sequencing

Phases 2–3 (Catalog → Stock → Sales) are ordered this way because each depends on the last — you cannot test FIFO sale consumption without stock batches, and you cannot enter stock batches without items existing. Phases 4–8 are more independent of each other and could be reordered based on what you need first (e.g., if you already have a business owner ready to test with, prioritize Phase 4 staff accounts over Phase 8 Super Admin tooling).

---

*Proceeding now with Phase 0 only, per your instruction.*
