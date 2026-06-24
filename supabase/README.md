# L!V!N Supabase Backend

This folder contains starter Supabase Edge Functions for the first paid-ticket path. They are intentionally server-side only: Stripe secret keys, webhook secrets, service-role keys, and APNs keys must never ship in the iOS app.

## SQL Setup Order

Run these files in the Supabase SQL Editor for a fresh dev project:

1. `schema.sql`
2. `rls_policies.sql`
3. `storage_policies.sql`
4. `rpc_functions.sql`
5. `realtime_tables.sql`

The live dev project currently uses `snaps.user_id` and the `create_direct_conversation(target_user_id uuid)` RPC. Keep those names aligned with the Swift models.

## Functions

- `create-ticket-checkout`: authenticated iOS client calls this to create a Stripe Checkout Session for a paid event.
- `stripe-webhook`: Stripe calls this after payment events so the database becomes the source of truth for ticket status.

## Required Supabase Secrets

Set these after linking the Supabase project:

```bash
supabase secrets set SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
supabase secrets set SUPABASE_ANON_KEY="YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY"
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="YOUR_SERVICE_ROLE_KEY"
supabase secrets set STRIPE_SECRET_KEY="sk_test_..."
supabase secrets set STRIPE_WEBHOOK_SECRET="whsec_..."
supabase secrets set LIVIN_APP_URL="livin://payments"
supabase secrets set LIVIN_WEB_URL="https://YOUR_DOMAIN.com"
```

## Deploy

```bash
supabase functions deploy create-ticket-checkout
supabase functions deploy stripe-webhook
```

Use Stripe test mode first. Do not enable paid public tickets until organizer onboarding, refunds, disputes, moderation, App Store policy review, and accounting are ready.
