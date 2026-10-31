// =============================================================================
// supabase/functions/check-subscription-status/index.ts
//
// !! NOT DEPLOYABLE — STUB ONLY !!
//
// This file captures the intended logic from docs/Module7_Companion_ChapaWebhook.md
// so the design is version-controlled alongside the schema. It is NOT ready
// to deploy. Every TODO below must be resolved before this function goes live.
//
// Purpose: enforce subscription lifecycle transitions that are not triggered
// by any user action. Intended to run on a daily schedule (via Supabase
// Scheduled Functions or pg_cron — see TODOs).
//
// Transitions applied:
//   active  → grace_period  when current_period_end  < now()
//   grace_period → restricted when grace_period_ends_at < now()
//
// Data is never deleted or modified during these transitions — only the
// status flag changes (Module 5 §3.4). The Flutter app's subscriptionProvider
// reads this status and gates local writes accordingly.
//
// This is the ONLY code path (along with chapa-webhook) permitted to write
// subscriptions.status (Rule 6 in structure.md).
// =============================================================================

// TODO: import the correct Supabase client version for the Deno runtime
//       that your Supabase project is currently running.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// TODO: decide on scheduling mechanism before deploying:
//   Option A — Supabase Scheduled Functions (dashboard-configured cron trigger)
//   Option B — pg_cron extension (add `select cron.schedule(...)` in a migration)
//   The choice affects how this function is invoked. For Scheduled Functions,
//   no HTTP trigger is needed — the runtime calls the default export directly.
//   For pg_cron calling an HTTP endpoint, you will need to add auth header
//   verification so arbitrary callers cannot trigger it.

Deno.serve(async (_req: Request) => {
  // Service-role client — bypasses RLS, intentional (same rationale as
  // chapa-webhook: subscription status must never be client-writable)
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const now = new Date().toISOString()

  // -- 1. active → grace_period ------------------------------------------------
  // Subscriptions whose current billing period has ended but haven't been
  // renewed yet. Grace period is 3 days (Module 5 §3.4).
  // TODO: verify that 3-day grace period figure against the final product
  //       decision before deploying.
  const { error: toGraceError } = await supabase
    .from('subscriptions')
    .update({
      status: 'grace_period',
      grace_period_ends_at: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
    })
    .eq('status', 'active')
    .lt('current_period_end', now)

  if (toGraceError) {
    console.error('Error transitioning active → grace_period:', toGraceError)
    // TODO: add alerting/observability before going to production
  }

  // -- 2. grace_period → restricted --------------------------------------------
  // Subscriptions whose grace period has also elapsed with no payment.
  const { error: toRestrictedError } = await supabase
    .from('subscriptions')
    .update({ status: 'restricted' })
    .eq('status', 'grace_period')
    .lt('grace_period_ends_at', now)

  if (toRestrictedError) {
    console.error('Error transitioning grace_period → restricted:', toRestrictedError)
    // TODO: add alerting/observability before going to production
  }

  // -- 3. trial → restricted (if trial expired with no payment) ----------------
  // TODO: confirm whether an expired trial with no payment goes directly to
  //       'restricted' or passes through 'grace_period' first. The current
  //       source docs are silent on this edge case.
  const { error: trialExpiredError } = await supabase
    .from('subscriptions')
    .update({ status: 'restricted' })
    .eq('status', 'trial')
    .lt('trial_ends_at', now)

  if (trialExpiredError) {
    console.error('Error transitioning expired trial → restricted:', trialExpiredError)
    // TODO: add alerting/observability before going to production
  }

  return new Response('OK', { status: 200 })
})
