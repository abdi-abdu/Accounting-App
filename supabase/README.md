# supabase/

This folder is the authoritative version-controlled record of everything in the Supabase backend: schema, seed data, and Edge Functions. Nothing in this folder connects to or modifies any live project — it is source code only.

---

## Structure

```
supabase/
  migrations/          schema changes, in order
  functions/           Deno/TypeScript Edge Functions
  seed.sql             idempotent reference data (subscription tiers)
  README.md            this file
```

---

## The "every change is a migration" rule

**Every** database change — tables, columns, indexes, RLS policies, functions, triggers, grants, enum values — goes in a new file in `migrations/` before or at the same time it is applied to any environment. This includes changes you test in the Supabase SQL Editor: write the migration file first, then paste it into the editor. Never make a schema change only through the SQL Editor without a corresponding migration file.

File naming: `<14-digit timestamp>_<short_description>.sql`

Example: `20241105143000_add_items_barcode_index.sql`

The timestamp is the moment you create the file (UTC, `YYYYMMDDHHmmss`). It does not need to match a Supabase CLI migration ID exactly — it just needs to sort correctly after all earlier files.

---

## The baseline file

`migrations/00000000000000_baseline.sql` is a **final-state snapshot** of everything deployed as of Phase 1. Its all-zeros timestamp ensures it sorts first.

⚠️ **Do NOT run the baseline against the live project.** It will fail immediately because all objects already exist. It is for fresh environments only (local dev, staging, CI).

To set up a new environment:
1. Apply `00000000000000_baseline.sql` first.
2. Run `seed.sql` to insert the Basic and Pro subscription tiers.
3. Apply any subsequent numbered migration files in order.

---

## Edge Functions

`functions/chapa-webhook/` and `functions/check-subscription-status/` are currently **non-deployable stubs**. They capture the intended logic from the design documents so it is version-controlled. Each file contains TODO comments that must be resolved before deployment. See `docs/Module7_Companion_ChapaWebhook.md` for the design rationale.

These two functions are the **only** code paths permitted to write `subscriptions.status` or insert `subscription_payments` rows. No client-side code may do this under any circumstances.

---

## Secrets

No secrets, keys, or credentials belong in this folder or anywhere in the repository. Supabase credentials go in `.env` (gitignored). The `SUPABASE_SERVICE_ROLE_KEY` used by Edge Functions is stored in Supabase's Edge Function environment secrets only — never in any committed file.
