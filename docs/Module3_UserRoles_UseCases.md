# Module 3: User Roles & Use Case Design
## Small Business Accounting & Inventory Management Platform (Multi-Tenant SaaS)

**Version:** 1.0 | **Date:** August 16, 2026
**Based on:** SRS v2.0 (approved)

---

## 1. User Roles — Detailed Permission Matrix

Three roles exist, defined by SRS v2.0 Section 2.1. The matrix below makes every permission explicit and unambiguous, since this directly drives Row Level Security (RLS) design in Module 6 (Supabase Schema).

| Capability | Super Admin | Owner | Staff |
|---|---|---|---|
| Sign up a new tenant business | — | ✅ (self-signup) | ❌ |
| View/manage all tenants across platform | ✅ | ❌ (own tenant only) | ❌ |
| View/manage own tenant's data | ❌ (not by default) | ✅ | ✅ (own tenant, restricted) |
| Create/deactivate Staff accounts | ❌ | ✅ | ❌ |
| Manage subscription plans/pricing (platform-wide) | ✅ | ❌ | ❌ |
| View/change own subscription tier | ❌ | ✅ | ❌ |
| Make subscription payment | ❌ | ✅ | ❌ |
| Restrict tenant on non-payment (system-triggered) | ✅ (oversight only; automatic) | ❌ | ❌ |
| Create/edit item categories | ❌ | ✅ | ❌ |
| Create/edit items | ❌ | ✅ | ❌ |
| Edit item master selling price | ❌ | ✅ | ❌ |
| Add stock (create stock batch) | ❌ | ✅ | ✅ |
| Record a sale | ❌ | ✅ | ✅ |
| Override sale price (per transaction only) | ❌ | ✅ | ✅ |
| Record an expense | ❌ | ✅ | ✅ |
| View expense totals / expense reports | ❌ | ✅ | ❌ |
| View profit reports (gross/net) | ❌ | ✅ | ❌ |
| View dashboard (financial figures) | ❌ | ✅ | ❌ (sees non-financial dashboard only) |
| View stock levels | ❌ | ✅ | ✅ |
| View low stock alerts | ❌ | ✅ | ✅ |
| Custom date-range reports (Pro) | ❌ | ✅ (if Pro) | ❌ |
| Sales trend charts (Pro) | ❌ | ✅ (if Pro) | ❌ |
| Export reports as PDF/Excel (Pro) | ❌ | ✅ (if Pro) | ❌ |
| Delete records (items, sales, etc.) | ❌ | ✅ | ❌ |
| View reconciliation alerts (sync overselling conflicts) | ❌ | ✅ | ❌ |
| Access a tenant's data via consented, time-limited support session | ✅ (only when granted) | ✅ (grants/revokes access) | ❌ |

**Design note:** Every row above becomes an enforceable Row Level Security policy in Supabase — not a client-side UI toggle. A Staff account attempting a forbidden action (e.g., editing item price via a crafted API request) must be rejected by the database itself.

---

## 2. Use Case Catalog

| ID | Use Case | Primary Actor(s) |
|---|---|---|
| UC-01 | Sign Up as New Tenant | Owner (prospective) |
| UC-02 | Login | Owner, Staff |
| UC-03 | Manage Staff Accounts | Owner |
| UC-04 | Manage Item Categories | Owner |
| UC-05 | Manage Items | Owner |
| UC-06 | Add Stock (Create Stock Batch) | Owner, Staff |
| UC-07 | Record a Sale | Owner, Staff |
| UC-08 | Record an Expense | Owner, Staff |
| UC-09 | View Dashboard | Owner, Staff |
| UC-10 | View Reports | Owner |
| UC-11 | Export Report (PDF/Excel) | Owner (Pro only) |
| UC-12 | Receive Low Stock Alert | Owner, Staff |
| UC-13 | Manage Subscription & Billing | Owner |
| UC-14 | Make Subscription Payment | Owner |
| UC-15 | Handle Payment Lapse / Grace Period | System, Owner |
| UC-16 | Manage Tenants (Platform-Wide) | Super Admin |
| UC-17 | Manage Subscription Plans | Super Admin |
| UC-18 | Monitor Platform Health | Super Admin |
| UC-19 | Sync Offline Data | System (background), Owner, Staff |
| UC-20 | Handle Sync Reconciliation Alert | System, Owner |

---

## 3. Detailed Use Case Specifications

### UC-01: Sign Up as New Tenant
- **Actor:** Prospective business owner
- **Preconditions:** None (new user)
- **Trigger:** User opens app and selects "Create Account"
- **Main Flow:**
  1. User provides business name, email/phone, and password
  2. System creates a new Tenant record and an Owner account linked to it (Supabase Auth)
  3. System starts a 30-day free trial (Basic-tier feature set, per confirmed decision)
  4. Owner is guided through initial setup: currency confirmation, first category/item creation
- **Postconditions:** New tenant exists, fully isolated from all others, trial countdown begins
- **Related FR:** New (Subscription section), 1.4, SRS Decisions Log #5, #8

### UC-02: Login
- **Actor:** Owner or Staff
- **Preconditions:** Account exists
- **Main Flow:**
  1. User enters credentials
  2. System authenticates via Supabase Auth and loads role + tenant scope
  3. App loads local offline data for that tenant (if previously synced) or performs initial sync if online
- **Exception Flow:** If subscription is restricted (past grace period), Owner sees a billing prompt on login; Staff sees a "service paused, contact your owner" message with read-only or no access, per FR-15
- **Related FR:** FR-11, FR-15 (new)

### UC-03: Manage Staff Accounts
- **Actor:** Owner
- **Preconditions:** Owner is logged in
- **Main Flow:**
  1. Owner navigates to Staff Management
  2. Owner adds a new staff member (name, login credential)
  3. System checks tier limit (Basic = 1, Pro = unlimited) before allowing creation
  4. If limit reached on Basic tier, system shows an upgrade prompt instead of creating the account
- **Alternate Flow:** Owner deactivates/removes an existing staff account
- **Postconditions:** Staff account created/removed, scoped only to Owner's tenant
- **Related FR:** FR-1.2, Section 5.1 tier table

### UC-04: Manage Item Categories
- **Actor:** Owner
- **Main Flow:** Owner creates, renames, or deactivates a category. Deactivating a category does not delete items already assigned to it (soft constraint).
- **Related FR:** FR-2.1–2.3

### UC-05: Manage Items
- **Actor:** Owner
- **Main Flow:**
  1. Owner creates an item: name, category, unit of measure, master selling price, reorder threshold, optional barcode field (inactive), optional image
  2. Owner may later edit the master price (Staff cannot)
  3. Owner may deactivate an item; historical sales/stock records referencing it remain intact
- **Related FR:** FR-3.1–3.4

### UC-06: Add Stock (Create Stock Batch)
- **Actor:** Owner or Staff
- **Main Flow:**
  1. User selects an item and enters quantity received + purchase cost for this batch + date
  2. System creates a new stock batch record (append-only)
  3. Item's displayed stock quantity updates as the sum of all unconsumed batches
- **Related FR:** FR-4.1–4.2, FR-4.6

### UC-07: Record a Sale
- **Actor:** Owner or Staff
- **Preconditions:** At least one active item exists
- **Main Flow:**
  1. User selects one or more items and quantities
  2. System pre-fills each line with the item's master price; user may override the price for this transaction only
  3. User confirms payment method (Cash, v1) and completes the sale
  4. System depletes stock from the oldest unconsumed batch(es) first (FIFO), computing COGS from actual batch cost(s)
  5. Sale record is saved locally immediately (offline-safe) and queued for sync
- **Exception Flow:** If sale quantity would reduce stock below zero, system blocks the sale with an error; if it would reduce stock to exactly zero, system shows a warning but allows it
- **Related FR:** FR-5.1–5.4, FR-4.5

### UC-08: Record an Expense
- **Actor:** Owner or Staff
- **Main Flow:** User selects/creates an expense category, enters amount, date, optional note. Staff can complete this but cannot subsequently view expense totals or reports.
- **Related FR:** FR-6.1–6.4

### UC-09: View Dashboard
- **Actor:** Owner or Staff
- **Main Flow:** User opens the app to the dashboard. System displays role-aware statistics — Owner sees revenue/profit/stock value/low-stock count/recent sales; Staff sees stock levels and low-stock alerts only, no financial figures.
- **Related FR:** FR-9.1–9.2

### UC-10: View Reports
- **Actor:** Owner
- **Main Flow:**
  1. Owner selects report period: Daily/Weekly/Monthly (all tiers), or Custom Date Range (Pro only)
  2. System computes revenue, COGS, gross profit, expenses, net profit, top-selling items for the period
  3. Pro-tier owners may additionally view sales trend/analytics charts
- **Related FR:** FR-8.1, FR-8.4–8.6

### UC-11: Export Report (PDF/Excel)
- **Actor:** Owner (Pro tier only)
- **Preconditions:** Owner's tenant is on Pro tier
- **Main Flow:** Owner selects a report and taps "Export." System generates a PDF or Excel file and opens the device's native share sheet.
- **Exception Flow:** If tenant is on Basic tier, system shows an upgrade prompt instead of generating the file.
- **Related FR:** FR-8.3

### UC-12: Receive Low Stock Alert
- **Actor:** Owner or Staff
- **Trigger:** An item's remaining stock (sum of unconsumed batches) falls at or below its configured reorder threshold
- **Main Flow:** System flags the item visually on the dashboard and item list. No push notification (in-app only, per SRS 1.4).
- **Related FR:** FR-10.1–10.2

### UC-13: Manage Subscription & Billing
- **Actor:** Owner
- **Main Flow:** Owner views current tier, trial/billing status, and payment history. Owner may upgrade Basic → Pro (or downgrade, with a warning if currently exceeding Basic limits, e.g., more than 1 staff account).
- **Related FR:** New Subscription section (Module 2 Section 5.1)

### UC-14: Make Subscription Payment
- **Actor:** Owner
- **Main Flow:**
  1. Owner selects a payment method (Telebirr, CBE Birr, bank transfer) via the integrated Chapa aggregator
  2. Owner completes payment through Chapa's flow
  3. Chapa confirms payment via webhook/callback to the backend
  4. System automatically updates the tenant's subscription status and renewal date — no manual approval step
- **Related FR:** SRS Decisions Log #10

### UC-15: Handle Payment Lapse / Grace Period
- **Actor:** System (automatic), Owner
- **Trigger:** Subscription renewal date passes without a confirmed payment, **or free trial period expires without a payment**
- **Main Flow:**
  1. System moves the tenant to `grace_period` and starts a 3-day grace countdown (this applies equally to an expired trial and a missed renewal — both follow the same path)
  2. Owner sees a persistent billing reminder banner in-app during the grace period; all features remain functional
  3. If payment is not received within 3 days, system restricts write access (cannot record new sales/stock/expenses) while preserving all existing data and read access
  4. Upon successful payment, restriction is automatically lifted
- **Related FR:** SRS Decisions Log #7, Section 2.3 principle #6

### UC-16: Manage Tenants (Platform-Wide)
- **Actor:** Super Admin
- **Main Flow:** Super Admin views a list of all tenants, their subscription tier, payment status, and trial/grace-period state. Super Admin may manually suspend or reactivate a tenant (e.g., for abuse or support reasons) but cannot view a tenant's operational data (items, sales, financials) without a separate, tenant-aware support-access mechanism (deferred — see note below).
- **Related FR:** SRS Section 2.1.1 (Tenant Isolation Principle)

### UC-17: Manage Subscription Plans
- **Actor:** Super Admin
- **Main Flow:** Super Admin defines/edits tier names, pricing, staff-account limits, and feature flags per tier (e.g., toggling which report features are Pro-exclusive) — ideally without requiring an app store release for pricing changes.
- **Related FR:** Module 2 Section 5.1

### UC-18: Monitor Platform Health
- **Actor:** Super Admin
- **Main Flow:** Super Admin views aggregate, anonymized platform metrics: total active tenants, trial conversions, monthly recurring revenue (MRR), churn, tier distribution. No per-tenant financial drill-down.
- **Related FR:** New (Platform Analytics — to be detailed in Module 5 architecture)

### UC-19: Sync Offline Data
- **Actor:** System (background process)
- **Trigger:** Device regains internet connectivity
- **Main Flow:** Locally queued records (sales, stock batches, expenses) are pushed to Supabase, tagged with the correct `business_id`. UI shows sync status per record/batch.
- **Related FR:** FR-11.1–11.3

### UC-20: Handle Sync Reconciliation Alert
- **Actor:** System, Owner
- **Trigger:** Post-sync detection that combined offline sales from multiple devices oversold an item (resulting stock < 0)
- **Main Flow:** System raises a reconciliation alert visible to the Owner, listing the affected item and conflicting sale records, so the Owner can manually resolve (e.g., contact the customer, adjust records, note as a loss).
- **Related FR:** FR-11.5

---

## 4. Resolved: Support Access Model (Confirmed)

**Decision:** Super Admin support access to tenant data is **consent-based, time-limited, and fully logged** — never standing/unrestricted access. This balances real support needs against the tenant-isolation and privacy commitments made in SRS v2.0.

### UC-21: Support Access to Tenant Data (Consent-Based)
- **Actor:** Super Admin, Owner
- **Preconditions:** Owner has an active support request/ticket
- **Main Flow:**
  1. Owner explicitly grants a support access window (e.g., taps "Allow support access for 48 hours" in-app, tied to a specific support request)
  2. Super Admin can view (read-only) the tenant's operational data only during this window
  3. Every access action is logged (who, when, what was viewed) and visible to the Owner afterward for transparency
  4. Access automatically expires at the end of the granted window; no renewal without a new explicit grant
- **Postconditions:** No standing access exists at any time; all access is auditable by the tenant
- **Related FR:** New (Support Access — to be detailed as FR-16 in Module 4/5)

---

*End of Module 3. All open items resolved. Ready to proceed to Module 4: Database Design (tables & relationships).*
