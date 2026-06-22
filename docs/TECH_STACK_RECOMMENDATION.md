# L!V!N Tech Stack Recommendation

Last updated: 2026-06-22

## Short Answer

Build the iOS app in native SwiftUI and use Supabase first.

Recommended MVP stack:

- App: Native SwiftUI + MapKit
- Backend: Supabase Auth, Postgres, Realtime, Storage, Edge Functions
- Website: Hostinger for the simple marketing site you already pay for
- Analytics: PostHog
- Crashes: Sentry
- Email: Resend
- Payments: Stripe later, not in the first friend TestFlight
- Deployment: Supabase Edge Functions first; add Railway or Render only when we need a separate custom API worker

This gives us the fastest real multiplayer TestFlight path without rebuilding the app in React Native or spreading the project across too many services.

## Why Not Switch To TypeScript/Tailwind For The App?

TypeScript + Tailwind is excellent for websites and React Native apps. NativeWind brings Tailwind-style classes to React Native, but L!V!N is already a native SwiftUI iOS app. Rebuilding the mobile app now would slow us down.

Use TypeScript/Tailwind for:

- Marketing site
- Admin dashboard
- Internal moderation console
- Landing page waitlist
- Future web profile pages

Keep SwiftUI for:

- Camera
- Location
- Maps
- Haptics
- TestFlight
- iOS-native feel

## Backend Choice

### Supabase

Best for this app right now.

Why:

- Official Swift client.
- Covers Auth, Postgres, Realtime, Storage, Edge Functions, and RLS.
- Postgres is flexible for geospatial/event/social data.
- Easier to inspect and migrate later.
- Strong fit for privacy rules like public/private accounts and friend-only snaps.

Use Supabase for:

- Accounts/profiles
- Follows
- Event joins
- Event group chat
- Snap metadata
- Media storage
- Saved places
- Realtime map updates
- APNs device tokens

### Convex

Very strong for realtime app development, and it has a Swift client. Convex is attractive if the highest priority is developer speed around live queries and TypeScript backend functions.

Why not first:

- L!V!N needs location/privacy/media/payment rules where Postgres + RLS is a strong foundation.
- Supabase is easier to pair with SQL, storage policies, and future analytics exports.
- Convex can still be revisited if Supabase Realtime becomes too heavy or slow for the product loop.

### Better Auth

Better Auth is strong for TypeScript apps, especially web/Expo. It is not the best first auth layer for this native SwiftUI app because Supabase Auth already comes with the backend stack we need.

Use Better Auth only if:

- We build a separate TypeScript web app with its own auth needs.
- We move the mobile client to React Native/Expo later.
- We decide to own auth fully in a custom backend.

## Deployment

### Supabase Edge Functions First

Use Supabase Edge Functions for:

- APNs sending
- signed storage URL generation
- moderation jobs
- server-only Stripe calls later
- webhook handlers later

This avoids adding Render/Railway/Hetzner before we need them.

### Railway

Good for quick custom APIs and workers. Usage-based pricing with a Hobby plan minimum makes it easy to start, but costs can grow if the app needs always-on workers or databases.

Use Railway when:

- We need a Node/TypeScript API that Edge Functions do not fit.
- We need background jobs that are easier outside Supabase.

### Render

Good for predictable hosted services, web services, background workers, and managed Postgres. Better when you want a traditional server/process model.

Use Render when:

- We build a long-running moderation worker.
- We build a web/admin backend separate from Supabase.

### Hetzner VPS

Cheapest at scale, most maintenance. Not the right first move unless you want to become ops person immediately.

Use Hetzner later when:

- Costs justify it.
- We need self-hosted workers or media processing.
- We are ready for backups, monitoring, security patches, deploy scripts, and incident handling.

### Hostinger

Use your existing subscription for the marketing site. Keep it separate from the app backend.

Good for:

- `livin.app` landing page
- waitlist
- press kit
- investor/community page
- download/TestFlight links

Not ideal for:

- realtime app backend
- event chat
- media upload APIs
- payment webhooks

## Money

### Stripe

Best for L!V!N paid tickets because this becomes a marketplace. Use Stripe Connect later so organizers can be paid and L!V!N can take a platform fee.

Recommended path:

1. Free events first.
2. Add organizer verification.
3. Add Stripe Connect onboarding.
4. Use server-side payment creation.
5. Use webhooks to unlock tickets.
6. Add refunds/disputes/reporting.

### Polar

Polar is useful for selling digital products, subscriptions, credits, or memberships quickly. It is less obviously perfect for a location/event marketplace with many real-world event hosts.

Use Polar for:

- L!V!N Pro subscription
- creator tools subscription
- digital guide products
- premium map packs

Use Stripe for:

- paid event tickets
- organizer payouts
- marketplace fee splits

## Signals

### PostHog

Use PostHog from the first TestFlight once consent/privacy copy is ready.

Track:

- onboarding completed
- map opened
- event expanded
- event joined
- route opened
- create snap opened
- snap posted
- follow tapped
- profile opened
- group chat message sent

Use feature flags for:

- new event scroll variants
- map pin styles
- onboarding versions
- tourist guide circles

### Sentry

Use Sentry before external TestFlight.

Track:

- crashes
- camera failures
- location permission failures
- route calculation failures
- Supabase networking errors
- slow launch/performance issues

### Resend

Use Resend for transactional email:

- waitlist confirmation
- email login or magic-link fallback
- TestFlight community updates
- organizer verification messages

Do not use email for core live chat or event notifications. That should be APNs.

## Plugin/Connector Reality In Codex

Useful installed/available now:

- XcodeBuildMCP: fastest way to build, run, inspect, screenshot, and test the iOS app.
- GitHub: repo, issues, PRs, commits, and review workflow.
- Stripe: installed now; useful once ticketing starts.
- Figma/Canva: useful later for design systems, decks, and marketing assets.
- Hostinger: installed now, but no callable Hostinger website creation tool is exposed in this Codex thread. Use the repo's `website/` folder and upload it through hPanel for now.

Not currently exposed as exact Codex plugins here:

- Supabase
- Convex
- PostHog
- Sentry
- Resend
- Railway
- Render
- Hetzner

For those, we will use official docs, SDKs, CLIs, and environment setup.

## Current Decision

Do this:

1. Keep SwiftUI.
2. Keep MapKit route preview now.
3. Add Supabase next.
4. Add PostHog and Sentry before external TestFlight.
5. Add Resend for waitlist/transactional email when the website exists.
6. Add Stripe only after free events prove the loop.
7. Add Google Places for California guide circles.
8. Add Google Navigation SDK only if route usage becomes core.

This stack keeps cost low and lets the product get real user feedback fast.

## Official References

- Supabase Swift: https://supabase.com/docs/reference/swift/introduction
- Supabase pricing: https://supabase.com/pricing
- Convex Swift: https://docs.convex.dev/client/swift
- Convex pricing: https://www.convex.dev/pricing
- Better Auth: https://www.better-auth.com
- Better Auth Apple: https://www.better-auth.com/docs/authentication/apple
- NativeWind: https://www.nativewind.dev
- Railway pricing: https://railway.com/pricing
- Render pricing: https://render.com/pricing
- Hetzner Cloud: https://www.hetzner.com/cloud
- Hostinger pricing: https://www.hostinger.com/pricing
- Stripe iOS payments: https://docs.stripe.com/payments/accept-a-payment?payment-ui=mobile&platform=ios
- Stripe Connect Accounts v2: https://docs.stripe.com/connect/accounts-v2
- Polar: https://polar.sh
- Polar pricing: https://polar.sh/resources/pricing
- Resend pricing: https://resend.com/pricing
- PostHog pricing: https://posthog.com/pricing
- Sentry iOS: https://docs.sentry.io/platforms/apple/guides/ios
- Sentry pricing: https://sentry.io/pricing
