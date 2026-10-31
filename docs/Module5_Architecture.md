# Module 5: Application Architecture
## Small Business Accounting & Inventory Management Platform (Multi-Tenant SaaS)

**Version:** 1.0 | **Date:** August 16, 2026
**Based on:** SRS v2.0, Module 3 (Roles/Use Cases), Module 4 (Database Design) — all approved

---

## 1. Architectural Style

**Offline-first, layered client architecture** with a **thin, security-heavy backend**. The guiding rule: the Flutter app should be able to do almost everything without Supabase ever responding, but should never be able to do anything Supabase's Row Level Security wouldn't also allow — the client is a *convenience layer*, not the source of truth for permissions.

**Overall shape:**
```
Flutter UI  →  Riverpod (state/application layer)  →  Repository layer  →  ┬→ Local DB (Drift/SQLite) [primary, always available]
                                                                            └→ Supabase (Postgres+RLS, Auth, Edge Functions) [synced when online]
```

---

## 1a. Platform Strategy (Revised)

**Target platforms:** Flutter Web first, with Android/iOS to follow later from the same codebase. Both must support full offline-first operation, including Staff sales entry (confirmed decision).

This requires a **platform-conditional storage backend** — the two platforms cannot share the exact same local database implementation:

| Platform | Local storage backend | Encryption at rest |
|---|---|---|
| **Web** | Drift over WebAssembly SQLite, persisted via OPFS (Origin Private File System) | **None** — no mature SQLCipher-equivalent exists for browser-based SQLite today. Data relies on standard browser storage sandboxing (same protection any website's local data gets), not a true encrypted file. This is a documented, accepted limitation, not an oversight. |
| **Mobile (later)** | Drift over native SQLite via SQLCipher | Full encryption at rest, per the original Module 5 decision, using `flutter_secure_storage` for key management |

The rest of the architecture (Riverpod layers, repository pattern, sync manager, RLS/Supabase backend) is **unchanged and platform-agnostic** — only the concrete local database connection differs, selected via Dart's conditional import mechanism so the rest of the app never needs to know which platform it's running on.

**Known web offline caveats worth carrying into implementation:**
- OPFS support is strong in Chrome/Edge, newer and less battle-tested in Safari — cross-browser offline reliability should be manually verified, not assumed
- Setting up the WASM SQLite worker typically requires specific web server headers (COOP/COEP) to enable the fast synchronous OPFS access path — this is a genuinely finicky setup step that should be verified against Drift's current official web documentation at implementation time, since the exact required files and headers have changed across Drift versions
- True offline PWA behavior (the browser tab surviving a refresh/reopen with data intact) also depends on the browser not evicting site storage — acceptable for a business-use tool where the shop uses the same browser/device consistently, but worth setting expectations that this is a different reliability model than a native mobile app

## 2. Layered Architecture (Client)

### 2.1 Presentation Layer (Flutter Widgets)
- Screens and widgets only. No business logic, no direct database calls.
- Reads state via Riverpod `ConsumerWidget`/`ConsumerStatefulWidget`.
- Role-aware rendering: widgets query the current user's role/tier from state and conditionally render (e.g., hide "Export" button for Basic tier, hide profit figures for Staff) — but this is a **UX convenience only**; the real enforcement is server-side (Module 4, Section 5).

### 2.2 Application/State Layer (Riverpod)
Organized by domain, mirroring the database design:
- `authProvider` — current session, role, business_id, tenant subscription status
- `itemsProvider`, `categoriesProvider` — catalog state
- `stockProvider` — derived stock levels (computed from batches, never stored directly, per FR-4.2)
- `salesProvider` — sale entry flow, cart/line-item state before commit
- `expensesProvider`
- `reportsProvider` — computed report data (tier-gated for custom ranges/charts)
- `subscriptionProvider` — trial/grace/restricted status, drives global UI banners and write-lock behavior
- `syncStatusProvider` — pending/synced/error state, surfaced globally (per FR-11.3)

Riverpod providers depend on the Repository layer below — they never talk to Drift or Supabase directly. This keeps state logic testable and swappable.

### 2.3 Domain Layer
Plain Dart models and business rules that are *storage-agnostic*:
- FIFO consumption calculation (given available batches + a sale quantity, determine which batches to draw from and at what cost) — this logic must exist once, here, and be used identically whether online or offline.
- Stock-to-zero/negative validation rule (FR-4.5).
- Tier-limit checks (staff count, feature flags) — mirrored from server-side rules so the UI can give instant feedback, but never trusted as the actual enforcement.

### 2.4 Data Layer (Repository Pattern)
One repository per domain (`ItemRepository`, `SalesRepository`, etc.), each responsible for:
- Reading/writing to the **local Drift database first**, always.
- Queuing a corresponding sync operation for Supabase.
- Never exposing Drift or Supabase specifics to the layers above — the rest of the app only knows "repositories," not "which database."

---

## 3. Offline-First & Sync Architecture

This is the most architecturally significant requirement in the whole system (FR-11.1–11.5), so it gets its own section.

### 3.1 Write Path (e.g., recording a sale)
1. User completes a sale in the UI.
2. Domain layer computes FIFO batch consumption and validates stock rules **entirely from local data**.
3. Repository writes the sale, sale items, and batch consumption records to the **local Drift database** in a single transaction — this is the point of durability (FR-11.1, NFR-4). The operation is complete from the user's perspective at this point, regardless of connectivity.
4. Repository appends a record to a local **sync queue table** (`pending_sync_operations`), tagged with the same `business_id` and a `device_id`.
5. A background **Sync Manager** watches connectivity (via `connectivity_plus` or equivalent) and, when online, drains the sync queue: pushing each queued operation to Supabase in order.
6. On successful push, the queue entry is marked synced; on failure (validation error, conflict), it's retried with backoff and surfaced via `syncStatusProvider`.

### 3.2 Read Path
- All UI reads come from the local Drift database, which acts as an offline cache/mirror of the tenant's Supabase data.
- On login (or reconnect after being offline), a **pull sync** fetches any remote changes not yet present locally (e.g., if the Owner used a second device) and merges them into Drift.

### 3.3 Conflict Handling
- Sales, stock batches, and expenses are **append-only** (Module 4, Principle 4) — two devices creating new records concurrently never conflict; both simply arrive.
- The only real conflict class is the **oversell scenario** (FR-11.5): stock arithmetic that only becomes inconsistent once multiple devices' sales are combined. This is **not prevented at write time** (impossible while offline) but **detected at sync time** by a Supabase-side check that runs after each incoming sale sync, which raises a `reconciliation_alerts` row when an item's total consumed quantity would exceed what was actually available.
- Item/category edits (Owner-only, infrequent) use simple **last-write-wins** by `updated_at`, which is acceptable given these are low-frequency, single-actor (Owner-only) writes.

### 3.4 Subscription-Gated Access
- `subscriptionProvider` checks tenant status on each app foreground/reconnect.
- If `status = restricted` (past grace period), the Repository layer blocks new local writes for sales/stock/expenses at the domain layer (not just hiding UI buttons) — reads remain fully available, per the "gate access, not data" principle (SRS 2.3.6).

---

## 4. Backend Architecture (Supabase)

| Component | Role |
|---|---|
| **Postgres** | Source of truth once synced; hosts all Module 4 tables |
| **Row Level Security** | Enforces tenant isolation (`business_id`) and role permissions (Module 3 matrix) at the database level |
| **Column-level security / restricted views** | Enforces Staff cost/COGS invisibility (Module 4, Section 5) |
| **Supabase Auth** | Issues JWTs carrying `role` and `business_id` claims, which RLS policies read directly — no separate permissions table lookup needed per request |
| **Edge Functions** | Host server-side logic that must run in a trusted environment: Chapa payment webhook handler, subscription status transitions (trial → active → grace → restricted), reconciliation-alert detection logic |
| **Realtime** | Optional: used to push subscription status changes or reconciliation alerts to a connected Owner's device immediately, rather than waiting for the next poll/sync cycle |
| **Storage** | Item images |

### 4.1 Why Edge Functions (not client-side logic) for Payments and Subscription State
The client must never be trusted to mark its own subscription as "paid" — that logic has to live server-side:
1. Owner initiates payment through Chapa from the Flutter app.
2. Chapa processes payment and calls a Supabase **Edge Function webhook** with the transaction result.
3. The Edge Function verifies the webhook signature, updates `subscription_payments` and `subscriptions` tables directly (bypassing client RLS entirely, using a service role).
4. The client's `subscriptionProvider` picks up the new status on next sync/poll (or instantly via Realtime).

---

## 5. Security Architecture Summary

1. **Authentication:** Supabase Auth (email/phone + password). JWT contains `sub` (user id), and custom claims `role` and `business_id` (set via a Postgres trigger/function reading the `profiles` table on token issuance).
2. **Row Level Security:** every operational table's policies filter on `business_id = auth.jwt() ->> 'business_id'`, plus role-based `USING`/`WITH CHECK` clauses matching the Module 3 permission matrix (e.g., Staff cannot `UPDATE items.master_selling_price`).
3. **Column-level security:** a Postgres view (e.g., `sale_items_staff_view`) excluding `unit_cogs`, exposed to Staff-role queries instead of the base table; Owners query the base table directly.
4. **Support access (UC-21):** implemented as a **time-limited RLS bypass** granted only while a corresponding non-expired row exists in `support_access_sessions` for that Super Admin + business — not a standing role.
5. **Local device security:** Drift database on-device should be encrypted at rest (e.g., via `sqlcipher_flutter_libs` or platform-level encryption) since it holds a full offline copy of financial data.

---

## 6. Reporting & Export Architecture

- **Daily/Weekly/Monthly/Custom reports:** computed **client-side** from local Drift data (fast, works offline, no backend load) using the domain layer's report-calculation functions.
- **PDF/Excel export (Pro, FR-8.3):** generated **on-device** using Flutter packages (e.g., `pdf` + `printing` for PDF, `syncfusion_flutter_xlsio` or `excel` package for `.xlsx`), then shared via the OS share sheet. No backend involvement needed — keeps this feature fully offline-capable too.
- **Sales trend charts (Pro, FR-8.6):** rendered client-side (e.g., `fl_chart` or `syncfusion_flutter_charts`) from the same locally computed aggregates.

---

## 7. Error Handling & Resilience

- All repository writes are wrapped in local transactions; a failure rolls back cleanly with no partial state.
- Sync failures are retried with exponential backoff and never block the UI thread or local operations.
- A global `syncStatusProvider` badge/banner communicates state honestly: "All changes saved" (synced), "Saved on this device, will sync when online" (pending), "Sync issue — tap for details" (error) — the wording matters, since these are financial records and the Owner needs to trust what "saved" means at all times.

---

## 8. High-Level Architecture Diagram

*(See the interactive diagram shared above — it shows the four client layers stacked on top of the Supabase backend, with the sync manager as the sole bridge between them, and Chapa as the one external integration point.)*

---

## 9. Design Decisions Worth Flagging

1. **Domain logic (FIFO, validation) lives in Dart, not SQL** — this lets the same rules run identically offline (against Drift) and can be mirrored server-side for defense-in-depth, without duplicating business logic in two languages.
2. **Reports and exports are fully client-side** — deliberate choice to keep Pro-tier features (custom ranges, charts, PDF/Excel) working offline, consistent with the offline-first principle, and to avoid backend compute costs as your tenant count grows.
3. **Payments never touch client-writable tables directly** — the Chapa webhook via Edge Function with a service role is the only path that can mark a subscription "paid," closing off any possibility of a client spoofing its own subscription status.
4. **Local database encryption is confirmed required for v1** (Section 10) — carried forward as a hard dependency into Module 6's folder structure and Module 7's implementation setup.

---

## 10. Resolved: Local Database Encryption

**Decision:** The on-device Drift/SQLite database **shall be encrypted at rest** in v1, using `sqlcipher_flutter_libs` (or equivalent) paired with Drift. The encryption key shall be generated per-device and stored in the OS-native secure keychain/keystore via `flutter_secure_storage` — never hardcoded, never stored alongside the database file itself. This closes off the risk of a lost/stolen device exposing a tenant's unencrypted sales, stock, and financial data, and avoids a much costlier retrofit-and-migrate effort later once real tenant data exists on-device.

This is now a hard requirement carried into Module 6 (Flutter folder structure) and Module 7 (Supabase schema), since it affects local database initialization code and dependency choices from the start of implementation.

---

*End of Module 5 — fully approved. Ready to proceed to Module 6: Flutter Folder Structure.*
