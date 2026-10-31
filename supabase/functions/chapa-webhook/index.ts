// =============================================================================
// supabase/functions/chapa-webhook/index.ts
//
// !! NOT DEPLOYABLE — STUB ONLY !!
//
// This file captures the intended logic from docs/Module7_Companion_ChapaWebhook.md
// so the design is version-controlled alongside the schema. It is NOT ready
// to deploy. Every TODO below must be resolved before this function goes live.
//
// Responsibilities:
//   1. Verify the request came from Chapa (signature check).
//   2. Record the payment attempt idempotently (chapa_reference dedup).
//   3. On success, advance the tenant's subscription to 'active' and set
//      current_period_end. On failure, record the failed payment only.
//
// This is the ONLY code path permitted to write subscriptions.status or
// insert subscription_payments rows (Rule 6 in structure.md).
// The service_role key is used here — it is stored in Edge Function secrets
// only, never shipped in the Flutter app.
// =============================================================================

// TODO: import the correct Supabase client version for the Deno runtime
//       that your Supabase project is currently running.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// TODO: confirm Chapa's actual webhook signature scheme before deploying.
//       Chapa's documentation should specify the header name, algorithm
//       (HMAC-SHA256 is common), and the secret source. The placeholder
//       below is illustrative only and must not be used as-is.
async function verifyChapaSignature(_req: Request): Promise<boolean> {
  // TODO: read Chapa's signature header (name TBC from Chapa docs)
  // TODO: compute HMAC-SHA256 of the raw request body using the webhook
  //       secret stored in Deno.env.get('CHAPA_WEBHOOK_SECRET')
  // TODO: compare in constant time (use a timing-safe comparison, not ===)
  // TODO: return false (not throw) on any mismatch so the caller can 401
  throw new Error('verifyChapaSignature not implemented — see TODOs above')
}

// TODO: map Chapa's payment method strings to the payment_method_type enum
//       values ('telebirr', 'cbe_birr', 'bank_transfer'). Chapa's actual
//       field names and values must be verified against their API docs.
function mapChapaMethodToEnum(_chapaMethod: string): string {
  // TODO: implement mapping
  throw new Error('mapChapaMethodToEnum not implemented — see TODOs above')
}

// TODO: replace with a proper date-math utility or verify this is sufficient
//       for month-end edge cases (e.g. Jan 31 + 1 month).
function addOneMonth(date: Date): Date {
  const d = new Date(date)
  d.setMonth(d.getMonth() + 1)
  return d
}

Deno.serve(async (req: Request) => {
  // -- 1. Signature verification -----------------------------------------------
  // TODO: uncomment once verifyChapaSignature is implemented
  // const isValid = await verifyChapaSignature(req)
  // if (!isValid) {
  //   return new Response('Invalid signature', { status: 401 })
  // }

  // -- 2. Parse payload ---------------------------------------------------------
  // TODO: validate that all required fields are present and correctly typed
  //       before destructuring. Chapa's exact payload shape must be confirmed
  //       from their webhook documentation.
  const payload = await req.json()
  const { tx_ref, status, amount, business_id, tier_id } = payload

  // -- 3. Service-role client (bypasses RLS — intentional, this is the only
  //        trusted writer of subscription/payment state) -----------------------
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // -- 4. Idempotency check (guard against Chapa webhook retries) ---------------
  const { data: existing } = await supabase
    .from('subscription_payments')
    .select('id')
    .eq('chapa_reference', tx_ref)
    .maybeSingle()

  if (existing) {
    return new Response('Already processed', { status: 200 })
  }

  // -- 5. Record the payment attempt --------------------------------------------
  // TODO: call mapChapaMethodToEnum(payload.method) once that helper is done
  const { error: insertError } = await supabase
    .from('subscription_payments')
    .insert({
      business_id,
      tier_id,
      amount,
      payment_method: payload.method, // TODO: replace with mapChapaMethodToEnum(payload.method)
      chapa_reference: tx_ref,
      status: status === 'success' ? 'confirmed' : 'failed',
      paid_at: status === 'success' ? new Date().toISOString() : null,
    })

  if (insertError) {
    console.error('Failed to insert subscription_payment:', insertError)
    return new Response('Internal error', { status: 500 })
  }

  // -- 6. On success, advance subscription to active ----------------------------
  if (status === 'success') {
    const nextPeriodEnd = addOneMonth(new Date())
    const { error: updateError } = await supabase
      .from('subscriptions')
      .update({
        tier_id,
        status: 'active',
        current_period_end: nextPeriodEnd.toISOString(),
        grace_period_ends_at: null, // clear any prior grace period
      })
      .eq('business_id', business_id)

    if (updateError) {
      console.error('Failed to update subscription:', updateError)
      // Payment row was already inserted — do not return 500 or Chapa will retry
      // and double-count. Log for manual reconciliation instead.
      // TODO: add alerting/observability here before going to production
    }
  }

  return new Response('OK', { status: 200 })
})
