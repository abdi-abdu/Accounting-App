# Software Requirements Specification (SRS)
## Small Business Accounting & Inventory Management App

**Version:** 2.0 (Revised — Multi-Tenant SaaS Model)
**Date:** August 16, 2026
**Prepared for:** Multi-tenant SaaS platform serving many independent small businesses, owned and operated by the platform developer
**Technology Stack:** Flutter (client), Riverpod (state management), local SQLite/Drift (offline cache), Supabase/PostgreSQL (cloud backend)

---

## 1. Introduction

### 1.1 Purpose
This document specifies the functional and non-functional requirements for a mobile-first **multi-tenant** Small Business Accounting and Inventory Management platform. The platform owner (referred to as **Super Admin**) offers this app as a paid subscription service to independent business owners ("Tenants"), each of whom manages their own shop's item categories, inventory, sales, expenses, and financial reporting — fully isolated from every other tenant — with full offline capability and cloud backup/sync.

### 1.2 Scope
**Revision note:** this scope supersedes the single-shop model from SRS v1.0. During requirements review, it was clarified that the platform owner intends to operate this as a **paid, multi-tenant SaaS product** — one app serving many unrelated business owners, each paying a recurring subscription fee.

The system shall support:
- **Many independent businesses ("Tenants")**, each fully data-isolated from every other tenant.
- Each Tenant is represented by one **Owner account**, who may create **Staff sub-accounts** scoped only to their own business.
- A **Super Admin** (the platform owner/developer) who oversees all tenants, subscription plans, billing status, and platform-wide health — but does **not** access a tenant's operational data (sales, stock, customers) as a matter of business trust, except where needed for support/billing purposes.
- **Subscription billing** with multiple pricing tiers, a free trial period, automated payment verification, and grace-period handling for lapsed payments.

The app must function fully **offline** for all core daily operations (sales, stock updates, expense entry) *within a tenant's own scope*, and synchronize automatically with a Supabase/PostgreSQL backend whenever internet connectivity is available.

### 1.3 Definitions

| Term | Meaning |
|---|---|
| COGS | Cost of Goods Sold — the purchase cost of items actually sold |
| FIFO | First-In-First-Out — costing method where the oldest purchased stock batch is depleted first when calculating COGS |
| Gross Profit | Revenue − COGS |
| Net Profit | Gross Profit − Operating Expenses |
| Stock Batch | A discrete addition of stock at a specific purchase cost and date |
| Master Price | The default, catalog selling price of an item, editable only by the Owner |
| Sale Override Price | A price entered at the point of sale that differs from the master price, applying only to that transaction |
| Sync | The background process of reconciling local offline data with the Supabase cloud database |
| Tenant | One independent business/shop using the platform, fully data-isolated from all other tenants |
| Super Admin | The platform owner/developer's account; manages tenants, subscription plans, and billing platform-wide |
| Subscription Tier | A pricing plan (e.g. Basic, Pro) that determines staff account limits and feature access for a tenant |
| Grace Period | A defined window after a subscription payment is due, during which the tenant retains access before being restricted |

### 1.4 Out of Scope (v2.0) — Reserved for Future Versions
The following were explicitly deferred during business analysis, but the schema and architecture must not block adding them later:
- Multi-branch / multi-location support **per tenant** (each tenant is still single-shop internally, for now)
- Tax calculation (VAT/GST/sales tax)
- Supplier management and formal Purchase Orders
- Customer accounts and credit/debt (accounts receivable) tracking
- Barcode scanning
- Sales returns and refunds
- Multi-currency support
- Push notifications (low stock alerts are in-app only for now)
- Price-override audit logging (who changed what price and when)
- International payment methods (Stripe/PayPal/card) — local Ethiopian methods only for v2.0
- Manual payment fallback (automated aggregator only, per confirmed decision)

---

## 2. Overall Description

### 2.1 User Classes

| Role | Description |
|---|---|
| **Super Admin** | Platform owner/developer. Manages tenant accounts, subscription plans, billing/payment status, and grace-period enforcement across the entire platform. Does not access a tenant's operational data (items, sales, stock, expenses) except for support purposes with the tenant's awareness. |
| **Owner** | Full access **within their own tenant only**. Can manage items, categories, prices, view all financial reports (gross & net profit), manage expenses, manage staff accounts, override sale prices, and view/manage their own subscription and billing status. |
| **Staff** | Restricted access **within their own tenant only**. Can record sales, view stock levels, record expenses, and override the sale price *for a single transaction only*. Cannot edit item master prices, cannot view profit/financial reports or expense totals, cannot delete records, cannot manage other users, cannot access billing/subscription settings. |

### 2.1.1 Tenant Isolation Principle
Every piece of operational data (items, categories, stock batches, sales, expenses) belongs to exactly one **Tenant**. No Owner or Staff account shall ever be able to read or write data belonging to a different tenant, enforced via Supabase Row Level Security using a `business_id` (tenant identifier) present on every operational table — not merely hidden in the UI.

### 2.2 Operating Environment
- Flutter app running on Android/iOS (mobile-first; tablet-friendly layout recommended for point-of-sale use)
- Local on-device database (SQLite via Drift or equivalent) as the source of truth for offline operation
- Supabase (PostgreSQL + Auth + Realtime) as the cloud backend for backup, sync, and reporting continuity
- Single fixed currency, configured once during setup

### 2.3 Design & Architectural Principles Driving Requirements
1. **Ledger, not state** — stock quantity is never stored as a single mutable number. It is always a *derived value* computed from a ledger of stock movements/batches. This is what allows FIFO costing and makes future features (returns, purchase orders, audit trail) additive rather than requiring redesign.
2. **Offline-first** — every core operation (sale, stock entry, expense entry) must succeed with zero network connectivity, queued for sync.
3. **One-way price flow** — sale-level price overrides read from the master price but never write back to it, enforced at the database layer (not only in UI), so staff cannot bypass restrictions.
4. **Extensibility over premature complexity** — v2.0 deliberately excludes several features (see 1.4) but the data model must accommodate them without breaking changes.
5. **Tenant isolation by default** — every operational table carries a tenant identifier (`business_id`), and Row Level Security policies must deny cross-tenant access at the database level, independent of any client-side logic.
6. **Subscription state gates access, not data** — when a tenant's subscription lapses past its grace period, their data is never deleted or hidden from them, but write access (and eventually read access) is restricted until payment resumes, per FR-12.

---

## 3. Functional Requirements

### 3.1 Authentication & Tenant/User Management
- FR-1.1: A new business owner shall be able to sign up, creating a new **Tenant** and an associated **Owner account**, via Supabase Auth.
- FR-1.2: The Owner shall be able to create Staff accounts scoped only to their own tenant, with a restricted permission set.
- FR-1.3: The Owner shall be able to deactivate/reactivate or delete Staff accounts within their own tenant.
- FR-1.4: The system shall enforce role-based **and** tenant-based permissions at the database level (Row Level Security), not solely in the Flutter UI.
- FR-1.5: The Super Admin shall have a separate administrative interface to view all tenants, their subscription status, and platform-wide metrics — without direct access to tenant operational data.

### 3.1a Subscription & Billing Management
- FR-12.1: New tenants shall automatically receive a **30-day free trial** upon sign-up, with full feature access during the trial (tier to be assigned at trial end).
- FR-12.2: The system shall offer at least two subscription tiers (e.g., Basic, Pro) that differ by: (a) maximum number of Staff accounts allowed, and (b) feature access (specific feature gating per tier to be defined in Module 2 addendum).
- FR-12.3: Payments shall be processed via an automated Ethiopian payment aggregator (e.g., Chapa), supporting Telebirr, CBE Birr, and bank transfers (e.g., CBE, Awash Bank).
- FR-12.4: Upon successful payment confirmation from the aggregator, the tenant's subscription status and expiry date shall update automatically without manual intervention.
- FR-12.5: If a subscription payment is not renewed by its due date, the tenant shall enter a **grace period** (duration to be defined) during which full access continues, accompanied by an in-app renewal reminder.
- FR-12.6: If payment is not received by the end of the grace period, the tenant's account shall be **restricted** (write access disabled) until payment resumes. Tenant data shall never be deleted for non-payment.
- FR-12.7: The Owner shall be able to view their own tenant's current plan, billing history, and subscription status within the app.
- FR-12.8: The Super Admin shall be able to view all tenants' subscription statuses, manually override/adjust a tenant's plan or status (e.g., for support/refund cases), and view aggregate subscription revenue.

### 3.2 Item Category Management
- FR-2.1: The Owner shall be able to create, edit, and deactivate item categories.
- FR-2.2: Each item must belong to exactly one category.
- FR-2.3: Categories shall support filtering of item lists and reports.

### 3.3 Item Management
- FR-3.1: The Owner shall be able to register a new item with: name, category, unit of measure, master selling price, optional barcode field (reserved, inactive in v1.0), reorder threshold (for low-stock alerts), and optional description/image.
- FR-3.2: Only the Owner may edit an item's master selling price.
- FR-3.3: Purchase cost is **not** a single field on the item — it is recorded per stock batch (see 3.4) to support FIFO costing.
- FR-3.4: The Owner shall be able to deactivate (soft-delete) items without losing historical sales/stock data tied to them.

### 3.4 Stock Management (Ledger-Based)
- FR-4.1: Adding stock shall create a new **stock batch** record containing: quantity added, purchase cost per unit, date added, and item reference.
- FR-4.2: Current stock quantity for an item shall be calculated as the sum of remaining (unconsumed) quantities across all its stock batches.
- FR-4.3: When a sale is recorded, stock shall be depleted from the **oldest unconsumed batch first** (FIFO), and that batch's purchase cost shall be used as the COGS for that sale line.
- FR-4.4: If a sale quantity spans multiple batches (e.g., oldest batch has insufficient quantity), the system shall split COGS calculation proportionally across the batches consumed.
- FR-4.5: The system shall allow a sale to reduce an item's stock down to exactly zero, displaying a warning. The system shall block (hard stop) any sale that would reduce stock below zero.
- FR-4.6: The data model shall support future stock movement types (purchase returns, sales returns, manual adjustments, supplier receipts) without schema changes to the core batch/movement structure.

### 3.5 Sales Recording
- FR-5.1: The system shall allow recording a sale consisting of one or more line items, each with: item, quantity, and price (defaulting to master price, overridable per line).
- FR-5.2: Staff shall be permitted to override the sale price per line item; this override shall apply only to that transaction and shall never alter the item's master price.
- FR-5.3: Each sale shall record: date/time, staff member who recorded it, total revenue, and total COGS (derived from FIFO batch consumption).
- FR-5.4: Payment method shall be recorded per sale using an extensible field (v1.0 supports "Cash" only, structured to allow additional methods later without schema change).

### 3.6 Expense Tracking
- FR-6.1: The Owner shall be able to create expense categories (e.g., Rent, Utilities, Salaries).
- FR-6.2: The Owner shall be able to record an expense with: category, amount, date, optional note.
- FR-6.3: Expenses shall feed into Net Profit calculations (Gross Profit − Expenses).
- FR-6.4: Staff shall be permitted to *record* new expenses (e.g., petty cash purchases), but shall **not** be able to view expense reports, totals, or any profit-related figures derived from expenses. This is a write-allowed, read-restricted permission — enforced via Row Level Security, not just UI hiding.

### 3.7 Financial Calculations
- FR-7.1: The system shall calculate **Gross Profit** = Total Revenue − Total COGS (FIFO-based).
- FR-7.2: The system shall calculate **Net Profit** = Gross Profit − Total Expenses.
- FR-7.3: Both Gross Profit and Net Profit shall be displayed separately and clearly labeled, never merged into a single ambiguous "profit" figure.

### 3.8 Reporting
- FR-8.1: The system shall generate Daily, Weekly, and Monthly reports covering: total revenue, total COGS, gross profit, total expenses, net profit, and top-selling items.
- FR-8.2: Reports shall be viewable in-app.
- FR-8.3: Reports shall be exportable as **PDF** and **Excel (.xlsx)** files, shareable via the device's native share sheet. **[Pro-tier only]**
- FR-8.4: Report date ranges shall use a standard midnight-to-midnight business day boundary (the shop closes before midnight, so no custom cutoff is required).
- FR-8.5: The system shall allow selecting a **custom date range** (any start/end date) for reports, in addition to the fixed daily/weekly/monthly presets. **[Pro-tier only]**
- FR-8.6: The system shall display **sales trend/analytics charts** (e.g., revenue over time, best/worst performing items) derived from existing sales and COGS ledger data. **[Pro-tier only]**

### 3.9 Dashboard
- FR-9.1: The dashboard shall display, at minimum: today's revenue, today's profit (gross & net), current stock value, number of low-stock items, and a short list of recent sales.
- FR-9.2: Dashboard figures shall be role-aware — Staff dashboard shall exclude profit and financial figures; Owner dashboard shall show full financials.

### 3.10 Low Stock Alerts
- FR-10.1: Each item shall have a configurable reorder threshold (minimum quantity).
- FR-10.2: The system shall visually flag items at or below their threshold on the dashboard and item list (in-app indicator; no push notifications in v1.0).

### 3.11 Offline & Sync
- FR-11.1: All core operations (sales, stock entry, expense entry) shall be fully functional with no network connection, scoped to the logged-in tenant's local data only.
- FR-11.2: Locally created/modified records shall be queued and automatically synced to Supabase when connectivity is restored, tagged with the correct `business_id` to preserve tenant isolation.
- FR-11.3: The UI shall indicate sync status (e.g., "Synced" / "Pending sync" / "Sync error") without blocking normal use.
- FR-11.4: Staff will use the app on **multiple devices simultaneously**. Since stock and sales are append-only ledger records (not overwritten values), concurrent offline sales from different devices will not corrupt each other's data — both are recorded independently on sync.
- FR-11.5: In the rare case where two offline devices both sell the same item such that combined sales exceed available stock (undetectable in real time while offline), the system shall, upon sync, detect the resulting negative stock condition and raise a **reconciliation alert** visible to the Owner, showing the affected item, the conflicting sales, and the resulting discrepancy — rather than silently allowing incorrect stock data to persist.

---

## 4. Non-Functional Requirements

- NFR-1: **Performance** — core screens (dashboard, item list, sale entry) shall load from local storage in under 1 second.
- NFR-2: **Data integrity** — financial calculations (COGS, profit) shall never be editable directly; they must always be derived from underlying transaction/batch data.
- NFR-3: **Security** — Supabase Row Level Security (RLS) shall enforce that (a) Staff accounts cannot read or write data outside their permitted scope, and (b) no tenant can ever read or write another tenant's data, independent of client-side checks.
- NFR-4: **Reliability** — no data loss on app crash or force-close; in-progress transactions shall be persisted locally before any network call is attempted.
- NFR-5: **Usability** — sale entry flow shall be optimized for speed (minimal taps) since it is the most frequently used feature.
- NFR-6: **Extensibility** — schema changes required to add any Section 1.4 "Out of Scope" feature shall be additive (new tables/columns), not breaking migrations of existing data.

---

## 5. Resolved Decisions Log (Module 1 & 2)

All clarifying questions raised during business analysis have been resolved:

| # | Question | Decision |
|---|---|---|
| 1 | Stock going negative | Warn and allow sale down to exactly zero; hard-block anything that would go below zero |
| 2 | Staff expense permissions | Staff can record expenses (write), but cannot view expense totals or profit reports (read-restricted) |
| 3 | Business day boundary | Standard midnight-to-midnight (shop closes before midnight) |
| 4 | Multi-device usage | Multiple staff will use the app on multiple devices simultaneously; ledger-based design absorbs this safely, with a reconciliation alert for the rare overselling edge case |
| 5 | **Business model (major revision)** | Platform is a **multi-tenant SaaS product**: the developer (Super Admin) hosts many independent business owners (Tenants), each paying a recurring subscription fee |
| 6 | Pricing structure | Multiple tiers (e.g. Basic/Pro), differentiated by staff account limits and feature access |
| 7 | Non-payment handling | Grace period after due date, then write-access restriction (data never deleted) |
| 8 | Trial period | 30-day free trial, chosen so tenants experience at least one full monthly report cycle before paying |
| 9 | Payment methods | Local Ethiopian methods only for v2.0 (Telebirr, CBE Birr, bank transfers) |
| 10 | Payment verification | Automated via a payment aggregator (e.g. Chapa) — no manual approval step |

### 5.1 Final Tier & Grace Period Decisions (Confirmed)

| Tier | Staff Accounts | Reports |
|---|---|---|
| **Basic** | 1 staff account | Daily/Weekly/Monthly presets, in-app view only |
| **Pro** | Unlimited staff accounts | All Basic reports **+** custom date-range reports (FR-8.5), sales trend/analytics charts (FR-8.6), and PDF/Excel export (FR-8.3) |

- **Future deferred features** (suppliers/POs, customer credit tracking, barcode scanning, sales returns — Section 1.4): tier placement (Basic vs Pro vs both) **will be decided individually when each feature is actually built**, not pre-committed now.

- **Grace period:** 3 days after a missed subscription payment before write-access is restricted (per architectural principle #6 — data is never deleted or hidden, only write access is gated).
- FR-8.3 is hereby scoped as a **Pro-tier feature**; Basic-tier accounts shall see reports in-app only, with an in-app upgrade prompt when export is attempted.
- FR-1.2 (Owner creates Staff accounts) is hereby constrained by tier: the system shall enforce the staff-count limit at creation time and prevent exceeding it, with an upgrade prompt shown to Basic-tier owners attempting a 2nd staff account.

---

*End of SRS v2.0 — fully approved. All open items resolved. Ready to proceed to Module 3: User Roles & Use Case Design.*
