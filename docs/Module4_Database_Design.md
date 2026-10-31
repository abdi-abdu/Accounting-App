# Module 4: Database Design
## Small Business Accounting & Inventory Management Platform (Multi-Tenant SaaS)

**Version:** 1.0 | **Date:** August 16, 2026
**Based on:** SRS v2.0 + Module 3 (Roles & Use Cases), both approved
**Target:** PostgreSQL via Supabase, with Row Level Security (RLS) for tenant isolation

---

## 1. Design Principles Carried Into This Schema

1. **Every operational table carries `business_id`** — enforced by RLS, not application code.
2. **Stock is a ledger, never a mutable number** — `stock_batches` + a consumption join table drive FIFO costing.
3. **Price override is one-way** — `sale_items.unit_price` is independent of `items.master_selling_price`; nothing writes back.
4. **Append-only where it matters** — sales, sale line items, stock batches, and batch consumption records are never updated/deleted in normal operation (only soft-deactivated), preserving audit integrity.
5. **Subscription state is separate from operational data** — a lapsed tenant's data is never touched; only a status flag gates write access.

---

## 2. Table Definitions

### 2.1 `businesses` (Tenants)
| Column | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| name | text | Business/shop name |
| owner_user_id | uuid, FK → auth.users | The Owner account for this tenant |
| currency_code | text | Fixed at setup (e.g. "ETB") |
| created_at | timestamptz | |
| is_active | boolean | Soft-disable by Super Admin (UC-16) |

### 2.2 `profiles` (extends Supabase `auth.users`)
| Column | Type | Notes |
|---|---|---|
| id | uuid, PK, FK → auth.users | 1:1 with Supabase Auth user |
| business_id | uuid, FK → businesses, **nullable** | Null only for Super Admin |
| role | enum('super_admin','owner','staff') | Drives RLS policies |
| full_name | text | |
| is_active | boolean | Owner can deactivate a Staff profile |
| created_at | timestamptz | |

*Note: Owner's own profile has `role='owner'` and `business_id` pointing to their own business. Staff profiles share the same `business_id` as their Owner.*

### 2.3 `subscription_tiers` (Platform-wide, managed by Super Admin)
| Column | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| name | text | "Basic", "Pro" |
| staff_account_limit | integer, nullable | 1 for Basic; null = unlimited (Pro) |
| monthly_price | numeric | In ETB |
| supports_custom_date_reports | boolean | FR-8.5 |
| supports_trend_charts | boolean | FR-8.6 |
| supports_export | boolean | FR-8.3 |
| is_active | boolean | Super Admin can retire a tier |

### 2.4 `subscriptions` (One active record per tenant)
| Column | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| business_id | uuid, FK → businesses, unique | One subscription per tenant |
| tier_id | uuid, FK → subscription_tiers | |
| status | enum('trial','active','grace_period','restricted') | Drives write-access gating |
| trial_ends_at | timestamptz | Set at signup (+30 days) |
| current_period_end | timestamptz | Renewal due date |
| grace_period_ends_at | timestamptz, nullable | Set when payment is missed (+3 days) |
| updated_at | timestamptz | |

### 2.5 `subscription_payments` (Payment history / audit trail)
| Column | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| business_id | uuid, FK → businesses | |
| tier_id | uuid, FK → subscription_tiers | Tier paid for |
| amount | numeric | |
| payment_method | enum('telebirr','cbe_birr','bank_transfer') | Extensible enum |
| chapa_reference | text | External transaction ID from Chapa |
| status | enum('pending','confirmed','failed') | Updated via Chapa webhook |
| paid_at | timestamptz, nullable | |
| created_at | timestamptz | |

### 2.6 `categories`
| Column | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| business_id | uuid, FK → businesses | Tenant scope |
| name | text | |
| is_active | boolean | Soft delete |

### 2.7 `items`
| Column | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| business_id | uuid, FK → businesses | |
| category_id | uuid, FK → categories | |
| name | text | |
| unit_of_measure | text | Free-text/dropdown, e.g. "piece", "kg" |
| master_selling_price | numeric | Owner-only editable (enforced via RLS + app logic) |
| reorder_threshold | numeric | For low-stock alerts (FR-10.1) |
| barcode | text, nullable | Reserved field, inactive in v1 |
| image_url | text, nullable | |
| is_active | boolean | Soft delete; historical records remain valid |
| created_at | timestamptz | |

### 2.8 `stock_batches` (Core of FIFO costing — append-only)
| Column | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| business_id | uuid, FK → businesses | |
| item_id | uuid, FK → items | |
| quantity_received | numeric | Original quantity added |
| quantity_remaining | numeric | Decremented as batches are consumed by sales |
| purchase_cost_per_unit | numeric | Locked at time of entry — this is what FIFO reads |
| received_at | timestamptz | Determines FIFO order (oldest first) |
| created_by | uuid, FK → profiles | Owner or Staff who added it |

*Current stock for an item = `SUM(quantity_remaining)` across its batches — never a stored/mutable single value (FR-4.2).*

### 2.9 `sales` (Header — append-only)
| Column | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| business_id | uuid, FK → businesses | |
| sold_by | uuid, FK → profiles | Owner or Staff who recorded it |
| sale_date | timestamptz | |
| payment_method | enum('cash') | Extensible for future methods (FR-5.4) |
| total_revenue | numeric | Denormalized sum of line items, for fast reporting |
| total_cogs | numeric | Denormalized sum of line COGS, for fast reporting |
| device_id | text | Identifies originating offline device, useful for FR-11.5 reconciliation |
| created_at | timestamptz | |

### 2.10 `sale_items` (Line items — append-only)
| Column | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| business_id | uuid, FK → businesses | Denormalized for simpler RLS |
| sale_id | uuid, FK → sales | |
| item_id | uuid, FK → items | |
| quantity | numeric | |
| unit_price | numeric | **The overridden or default price actually charged** — independent of `items.master_selling_price` (FR-5.2) |
| unit_cogs | numeric | Weighted cost across consumed batches, for this line |

### 2.11 `sale_item_batch_consumption` (FIFO detail — the actual ledger)
| Column | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| sale_item_id | uuid, FK → sale_items | |
| stock_batch_id | uuid, FK → stock_batches | Which batch was drawn from |
| quantity_consumed | numeric | Portion of this sale filled from this batch |
| cost_per_unit_snapshot | numeric | Copied from the batch at time of sale (immutable even if batch data changes later) |

*This table is what makes FR-4.3/4.4 (FIFO across possibly multiple batches) queryable and auditable — a sale line can reference more than one batch.*

### 2.12 `expense_categories`
| Column | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| business_id | uuid, FK → businesses | |
| name | text | e.g. "Rent", "Utilities" |
| is_active | boolean | |

### 2.13 `expenses`
| Column | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| business_id | uuid, FK → businesses | |
| category_id | uuid, FK → expense_categories | |
| amount | numeric | |
| expense_date | timestamptz | |
| note | text, nullable | |
| recorded_by | uuid, FK → profiles | Owner or Staff (FR-6.4: write-allowed, read-restricted for Staff) |

### 2.14 `reconciliation_alerts` (Sync conflict tracking — FR-11.5)
| Column | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| business_id | uuid, FK → businesses | |
| item_id | uuid, FK → items | |
| description | text | e.g. "Oversold by 2 units across 2 devices" |
| related_sale_ids | uuid[] | Sales involved in the conflict |
| status | enum('open','resolved') | |
| created_at | timestamptz | Set when detected post-sync |

### 2.15 `support_access_sessions` (Consent-based Super Admin access — UC-21)
| Column | Type | Notes |
|---|---|---|
| id | uuid, PK | |
| business_id | uuid, FK → businesses | |
| granted_by | uuid, FK → profiles | The Owner who granted access |
| super_admin_id | uuid, FK → profiles | Which Super Admin was granted access |
| reason | text | Tied to a support request |
| granted_at | timestamptz | |
| expires_at | timestamptz | Auto-expiry (e.g. +48h) |
| revoked_at | timestamptz, nullable | Manual early revocation by Owner |

---

## 3. Entity Relationship Summary

```
businesses ──1:1──> subscriptions ──N:1──> subscription_tiers
businesses ──1:N──> subscription_payments
businesses ──1:N──> profiles (owner + staff)
businesses ──1:N──> categories ──1:N──> items
items ──1:N──> stock_batches
businesses ──1:N──> sales ──1:N──> sale_items ──1:N──> sale_item_batch_consumption ──N:1──> stock_batches
businesses ──1:N──> expense_categories ──1:N──> expenses
businesses ──1:N──> reconciliation_alerts
businesses ──1:N──> support_access_sessions
```

Every table except `subscription_tiers` (platform-global) carries `business_id`, which is the single column Row Level Security policies will filter on — this is the enforcement point for tenant isolation (SRS Section 2.1.1).

---

## 4. Key Design Decisions Worth Flagging

1. **Denormalized totals on `sales`** (`total_revenue`, `total_cogs`): technically derivable from `sale_items`, but stored redundantly for fast dashboard/report queries without expensive joins on every load. Kept in sync at write-time only (sales are append-only, so no update-drift risk).
2. **`device_id` on `sales`**: added specifically to support the FR-11.5 reconciliation alert — without it, we couldn't identify *which* two devices conflicted after sync.
3. **No `quantity` column on `items`**: intentional. Stock is always computed, never stored, per FR-4.2 — this is the single most important structural decision in the whole schema.
4. **`unit_price` on `sale_items`, not linked to `items.master_selling_price` at query time**: this guarantees historical sales always show what was *actually charged*, even if the master price changes later.

---

## 5. Resolved: Staff Cost Visibility

**Decision:** Staff accounts shall **never** see `purchase_cost_per_unit` (on `stock_batches`), `unit_cogs` (on `sale_items`), `total_cogs` (on `sales`), or any derived profit/margin figures. Staff-facing queries and RLS policies must exclude these columns entirely — not merely hide them in the Flutter UI, since a Staff account could otherwise query the API directly and see raw cost data.

This will be implemented via **column-level security** in Supabase: either a restricted Postgres view exposing only Staff-permitted columns, or explicit column grants tied to the `profiles.role` claim, enforced alongside the row-level `business_id` policies.

---

*End of Module 4. All open items resolved. Ready to proceed to Module 5: Application Architecture.*
