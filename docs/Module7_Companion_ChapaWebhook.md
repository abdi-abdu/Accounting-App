# Module 7 Companion: Chapa Payment Webhook (Supabase Edge Function)

**Why this isn't in the SQL file:** this logic must run in a trusted server environment using the `service_role` key (which bypasses RLS entirely), verify a webhook signature, and make an authenticated call back to Chapa to confirm the transaction — none of which belongs in the database layer. This is a Deno/TypeScript Edge Function, deployed via the Supabase CLI.

## Structure

```
supabase/functions/chapa-webhook/index.ts
```

## Responsibilities (pseudocode-level, not final implementation)

```typescript
// supabase/functions/chapa-webhook/index.ts

import { createClient } from '@supabase/supabase-js'

Deno.serve(async (req) => {
  // 1. Verify the request genuinely came from Chapa
  //    (validate signature/secret header per Chapa's webhook docs)
  const isValid = verifyChapaSignature(req)
  if (!isValid) {
    return new Response('Invalid signature', { status: 401 })
  }

  const payload = await req.json()
  const { tx_ref, status, amount, business_id, tier_id } = payload

  // 2. Use the service_role client — bypasses RLS entirely, since this
  //    function is the ONLY trusted writer of subscription/payment state
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // 3. Record the payment attempt (idempotent — check tx_ref not already processed)
  const { data: existing } = await supabase
    .from('subscription_payments')
    .select('id')
    .eq('chapa_reference', tx_ref)
    .maybeSingle()

  if (existing) {
    return new Response('Already processed', { status: 200 }) // idempotency
  }

  await supabase.from('subscription_payments').insert({
    business_id,
    tier_id,
    amount,
    payment_method: mapChapaMethodToEnum(payload.method),
    chapa_reference: tx_ref,
    status: status === 'success' ? 'confirmed' : 'failed',
    paid_at: status === 'success' ? new Date().toISOString() : null,
  })

  // 4. If successful, update the tenant's subscription status and renewal date
  if (status === 'success') {
    const nextPeriodEnd = addOneMonth(new Date())
    await supabase.from('subscriptions').update({
      tier_id,
      status: 'active',
      current_period_end: nextPeriodEnd.toISOString(),
      grace_period_ends_at: null, // clear any prior grace period
    }).eq('business_id', business_id)
  }

  return new Response('OK', { status: 200 })
})
```

## Related Scheduled Function: Grace Period Enforcement

A second, scheduled Edge Function (triggered via `pg_cron` or Supabase Scheduled Functions, running e.g. daily) handles the transition from `active` → `grace_period` → `restricted`, since this isn't triggered by any user action:

```typescript
// supabase/functions/check-subscription-status/index.ts (scheduled daily)

// For each subscription where trial_ends_at < now() and status = 'trial':
//   → set status = 'grace_period', grace_period_ends_at = now() + 3 days
//   (expired trials enter the same grace period as missed payments — not immediate restriction)

// For each subscription where current_period_end < now() and status = 'active':
//   → set status = 'grace_period', grace_period_ends_at = now() + 3 days

// For each subscription where grace_period_ends_at < now() and status = 'grace_period':
//   → set status = 'restricted'
//   (Data is never touched — only the status flag changes, per Module 5 Section 3.4;
//    the Flutter app's subscriptionProvider reads this status and gates local writes)
```

## Security Notes

- The `service_role` key is stored only in the Edge Function's environment secrets — **never** shipped in the Flutter app or exposed to any client.
- Idempotency (checking `chapa_reference` before inserting) protects against Chapa retrying a webhook delivery and accidentally double-crediting a payment.
- This is the **only** code path in the entire system permitted to change `subscriptions.status` — reinforcing the Module 5 principle that clients can never self-report their own payment status.

---

*This companion document completes Module 7. Both the SQL schema and this webhook structure are ready for your review together.*
