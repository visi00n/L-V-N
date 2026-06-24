# L!V!N Setup Guide

This guide is the practical setup path for turning the local prototype into a real multiplayer TestFlight app while keeping costs low.

Recommended MVP stack:

- iOS app: native SwiftUI, MapKit now, Google Places later.
- Backend: Supabase Auth, Postgres, Realtime, Storage, Edge Functions.
- Payments: Stripe Connect + Checkout later; all MVP events stay free until the social loop works.
- Notifications: APNs from a Supabase Edge Function.
- Signals: PostHog for product analytics, Sentry for crashes, Resend for email.
- Website: static Hostinger landing page from the `website/` folder.

Official docs used:

- GitHub repository setup: https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository
- GitHub remotes: https://docs.github.com/en/get-started/git-basics/about-remote-repositories
- Supabase iOS SwiftUI quickstart: https://supabase.com/docs/guides/getting-started/quickstarts/ios-swiftui
- Supabase Swift reference: https://supabase.com/docs/reference/swift/introduction
- Supabase RLS: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase Realtime: https://supabase.com/docs/guides/realtime
- Supabase Storage access control: https://supabase.com/docs/guides/storage/security/access-control
- Supabase Edge Functions: https://supabase.com/docs/guides/functions
- Apple APNs registration: https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns
- Google Maps SDK for iOS: https://developers.google.com/maps/documentation/ios-sdk
- Google Places SDK for iOS: https://developers.google.com/maps/documentation/places/ios-sdk/overview
- Google Navigation SDK for iOS: https://developers.google.com/maps/documentation/navigation/ios-sdk
- Stripe iOS payments: https://docs.stripe.com/payments/accept-a-payment?payment-ui=mobile&platform=ios
- Stripe Connect Accounts v2: https://docs.stripe.com/connect/accounts-v2
- Stripe Checkout Sessions: https://docs.stripe.com/api/checkout/sessions
- Stripe destination charges: https://docs.stripe.com/connect/destination-charges
- PostHog iOS: https://posthog.com/docs/libraries/ios
- Sentry iOS: https://docs.sentry.io/platforms/apple/guides/ios/
- Resend API keys: https://resend.com/docs/dashboard/api-keys/introduction

## Cost Strategy

Start with:

- GitHub private repo: free for the prototype.
- Supabase Free: enough to validate auth, profiles, events, snaps, chat, and storage with a small tester group.
- Apple Developer Program: required for TestFlight and APNs, currently 99 USD per membership year in the US.
- MapKit first: already in the app, no Google bill for the MVP route preview.
- Google Maps/Places later: enable billing but restrict keys. Use Places only for guide spot discovery and saved place metadata at first.
- PostHog, Sentry, and Resend: start on free tiers with low tester volume.
- Stripe later: keep events free until auth, database, moderation, refunds, and organizer trust are ready.

Do not add paid tickets to the first TestFlight build. Ship social proof first: account, snap map, event signup, event group chat, profiles, follows, and notifications.

## 1. GitHub Setup

Current local status:

- GitHub CLI is installed.
- The machine is authenticated as `visi00n`.
- `origin` points to `https://github.com/visi00n/L-V-N.git`.
- Current update branch is `codex/livin-prototype-stack-and-visuals`.
- Pull requests should be ready for review, not draft, and use titles like `APP UPDATES: Event scroll and setup guide`.

### Daily Update Flow

Use this for every app update:

```bash
cd /Users/laptcv/Desktop/LIVE
git status
git add .
git commit -m "APP UPDATES: short clear update name"
git push
gh pr create --title "APP UPDATES: short clear update name" --body "Update summary." --base main --head YOUR_BRANCH
```

If a PR already exists for the branch, just push. GitHub updates the PR automatically.

### Option A: Create the repo from GitHub.com

1. Go to https://github.com/new.
2. Repository name: `LIVIN` or `LIVE`.
3. Visibility: `Private` for now.
4. Do not initialize with README, `.gitignore`, or license because this local repo already has files.
5. Click Create repository.
6. Copy the HTTPS repo URL. It will look like:

```bash
https://github.com/visi00n/LIVIN.git
```

7. In this project folder, connect it:

```bash
cd /Users/laptcv/Desktop/LIVE
git remote add origin https://github.com/visi00n/LIVIN.git
git remote -v
```

8. Commit and push:

```bash
git add .
git commit -m "Set up L!V!N prototype"
git push -u origin main
```

### Option B: Create it from terminal with GitHub CLI

Use this when you know the repo name and want it private:

```bash
cd /Users/laptcv/Desktop/LIVE
gh repo create visi00n/LIVIN --private --source=. --remote=origin
git add .
git commit -m "Set up L!V!N prototype"
git push -u origin main
```

### Suggested GitHub Sections

Create these labels:

- `mvp`
- `ios`
- `backend`
- `supabase`
- `map`
- `notifications`
- `payments`
- `testflight`
- `design`

Create these milestones:

- `MVP TestFlight`
- `Realtime Social`
- `California Guide`
- `Paid Tickets`

Create these first issues:

1. `Supabase auth and profile setup`
2. `Realtime event group chat`
3. `Live snap upload to storage`
4. `Snap map from database`
5. `Follow and profile notifications`
6. `California guide places layer`
7. `APNs device token registration`
8. `Stripe ticketing research only`

## 2. Supabase Setup

Supabase should be the first real backend because one service can cover:

- Auth
- Postgres database
- Row Level Security
- Realtime messages
- Storage for snap photos
- Edge Functions for secure server-side actions

Current project-specific setup is tracked in:

```text
/Users/laptcv/Desktop/LIVE/docs/SUPABASE_SETUP.md
```

Run the actual SQL files from the repo, not older pasted chat snippets:

```text
/Users/laptcv/Desktop/LIVE/supabase/schema.sql
/Users/laptcv/Desktop/LIVE/supabase/rls_policies.sql
/Users/laptcv/Desktop/LIVE/supabase/storage_policies.sql
/Users/laptcv/Desktop/LIVE/supabase/realtime_tables.sql
```

The active Supabase project URL for Swift is:

```text
https://wppernaddlrwjgcmikyj.supabase.co
```

The `/rest/v1/` Data API URL shown in Supabase is not the value used in `SupabaseClient`.

### Create the Project

1. Go to https://database.new.
2. Project name: `livin-prod` or `livin-dev`.
3. Region: choose the closest US region to California users.
4. Generate a strong database password and save it in a password manager.
5. Wait for the project to finish provisioning.

### Get Client Keys

1. Open the Supabase project dashboard.
2. Go to Connect or Project Settings > API Keys.
3. Copy:
   - Project URL
   - Publishable key, usually `sb_publishable_...`
4. Do not put a secret key in the iOS app.

### Add the Swift Package

In Xcode:

1. File > Add Package Dependencies.
2. Add:

```text
https://github.com/supabase/supabase-swift
```

3. Add the `Supabase` product to the LIVE app target.

### Store Local Config

Add a debug-only config file later, but do not commit real production secrets. The client publishable key can live in the app, but it should still be managed cleanly.

Suggested future file:

```swift
enum LiveConfig {
    static let supabaseURL = URL(string: "YOUR_SUPABASE_URL")!
    static let supabasePublishableKey = "YOUR_SUPABASE_PUBLISHABLE_KEY"
}
```

Then initialize:

```swift
import Supabase

let supabase = SupabaseClient(
    supabaseURL: LiveConfig.supabaseURL,
    supabaseKey: LiveConfig.supabasePublishableKey
)
```

### Database Schema

Run this in Supabase SQL Editor for the first MVP schema:

```sql
create extension if not exists "pgcrypto";

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  handle text unique not null,
  display_name text not null,
  bio text default '',
  avatar_url text,
  is_private boolean not null default true,
  venture_score integer not null default 0,
  streak_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  details text not null default '',
  category text not null default 'Social',
  starts_at timestamptz not null,
  ends_at timestamptz,
  location_name text not null,
  latitude double precision not null,
  longitude double precision not null,
  is_paid boolean not null default false,
  ticket_price_cents integer,
  capacity integer,
  created_at timestamptz not null default now()
);

create table public.event_members (
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

create table public.snaps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  attached_event_id uuid references public.events(id) on delete set null,
  caption text not null default '',
  location_name text not null,
  latitude double precision not null,
  longitude double precision not null,
  first_media_path text not null,
  media_count integer not null default 1,
  created_at timestamptz not null default now()
);

create table public.snap_media (
  id uuid primary key default gen_random_uuid(),
  snap_id uuid not null references public.snaps(id) on delete cascade,
  storage_path text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.event_messages (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create table public.saved_places (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  source text not null default 'manual',
  google_place_id text,
  latitude double precision not null,
  longitude double precision not null,
  folder_name text not null default 'Want to go',
  created_at timestamptz not null default now()
);

create table public.guide_places (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text not null default '',
  category text not null default 'Guide',
  source text not null default 'curated',
  google_place_id text,
  latitude double precision not null,
  longitude double precision not null,
  photo_url text,
  city text not null default 'California',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  platform text not null default 'ios',
  environment text not null default 'sandbox',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

create table public.stripe_connect_accounts (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  stripe_account_id text unique not null,
  charges_enabled boolean not null default false,
  payouts_enabled boolean not null default false,
  details_submitted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.ticket_orders (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  stripe_checkout_session_id text unique,
  stripe_payment_intent_id text,
  amount_cents integer not null,
  platform_fee_cents integer not null,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.follows enable row level security;
alter table public.events enable row level security;
alter table public.event_members enable row level security;
alter table public.snaps enable row level security;
alter table public.snap_media enable row level security;
alter table public.event_messages enable row level security;
alter table public.saved_places enable row level security;
alter table public.guide_places enable row level security;
alter table public.device_tokens enable row level security;
alter table public.stripe_connect_accounts enable row level security;
alter table public.ticket_orders enable row level security;
```

### MVP RLS Policies

These policies are intentionally simple. We should tighten them before a real public launch.

```sql
create policy "profiles visible to authenticated users"
on public.profiles for select
to authenticated
using (
  is_private = false
  or id = auth.uid()
  or exists (
    select 1 from public.follows f
    where f.follower_id = auth.uid()
    and f.following_id = profiles.id
  )
);

create policy "users update own profile"
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy "users insert own profile"
on public.profiles for insert
to authenticated
with check (id = auth.uid());

create policy "public events are readable"
on public.events for select
to authenticated
using (true);

create policy "users create events"
on public.events for insert
to authenticated
with check (host_id = auth.uid());

create policy "event hosts update events"
on public.events for update
to authenticated
using (host_id = auth.uid())
with check (host_id = auth.uid());

create policy "memberships visible"
on public.event_members for select
to authenticated
using (true);

create policy "users join as themselves"
on public.event_members for insert
to authenticated
with check (user_id = auth.uid());

create policy "users leave own membership"
on public.event_members for delete
to authenticated
using (user_id = auth.uid());

create policy "visible snaps"
on public.snaps for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = snaps.user_id
    and (
      p.is_private = false
      or p.id = auth.uid()
      or exists (
        select 1 from public.follows f
        where f.follower_id = auth.uid()
        and f.following_id = p.id
      )
    )
  )
);

create policy "users create own snaps"
on public.snaps for insert
to authenticated
with check (user_id = auth.uid());

create policy "snap media readable with snap"
on public.snap_media for select
to authenticated
using (
  exists (
    select 1 from public.snaps s
    where s.id = snap_media.snap_id
  )
);

create policy "event members read messages"
on public.event_messages for select
to authenticated
using (
  exists (
    select 1 from public.event_members em
    where em.event_id = event_messages.event_id
    and em.user_id = auth.uid()
  )
);

create policy "event members send messages"
on public.event_messages for insert
to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.event_members em
    where em.event_id = event_messages.event_id
    and em.user_id = auth.uid()
  )
);

create policy "users manage saved places"
on public.saved_places for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "active guide places are readable"
on public.guide_places for select
to authenticated
using (is_active = true);

create policy "users manage own device tokens"
on public.device_tokens for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "organizers read own stripe account"
on public.stripe_connect_accounts for select
to authenticated
using (user_id = auth.uid());

create policy "buyers read own ticket orders"
on public.ticket_orders for select
to authenticated
using (buyer_id = auth.uid());
```

The service-role key inside Edge Functions bypasses RLS for trusted server tasks like Stripe webhooks and APNs sending. Never put the service-role key in the iOS app.

### Storage Buckets

Create these Supabase Storage buckets:

- `snap-media`: private
- `avatars`: public or private with signed URLs

Recommended MVP:

- Use private `snap-media`.
- Upload compressed JPEGs.
- Store the storage path in `snaps.first_media_path` and `snap_media.storage_path`.
- Generate signed URLs when loading details.

Storage policy starter:

```sql
create policy "users upload snap media"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'snap-media'
  and owner = auth.uid()
);

create policy "users read own snap media"
on storage.objects for select
to authenticated
using (
  bucket_id = 'snap-media'
  and owner = auth.uid()
);
```

Before public launch, add a server-side check that allows friends/public viewers to receive signed URLs for snaps they are allowed to view.

### Realtime

Use:

- Realtime Postgres changes for MVP chat and snap map updates.
- Broadcast later for high-volume event rooms.
- Presence later for "who is here now" in event group chats.

Enable Realtime for these tables:

- `snaps`
- `event_messages`
- `event_members`

Suggested app behavior:

- Subscribe to `snaps` for map updates.
- Subscribe to `event_messages` filtered by joined event.
- Subscribe to `event_members` so event counts update live.

### Edge Functions Setup

Use Edge Functions for anything that needs a secret or elevated database permission:

- Stripe Checkout Session creation.
- Stripe webhooks.
- APNs sending.
- Signed URL generation for private snap media.
- Moderation jobs.
- Organizer payout/account refresh.

Install and link the Supabase CLI:

```bash
brew install supabase/tap/supabase
supabase login
cd /Users/laptcv/Desktop/LIVE
supabase init
supabase link --project-ref YOUR_PROJECT_REF
```

The repo already includes starter functions in:

```text
supabase/functions/create-ticket-checkout/index.ts
supabase/functions/stripe-webhook/index.ts
```

Set required secrets:

```bash
supabase secrets set SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
supabase secrets set SUPABASE_ANON_KEY="YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY"
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="YOUR_SERVICE_ROLE_KEY"
supabase secrets set STRIPE_SECRET_KEY="sk_test_..."
supabase secrets set STRIPE_WEBHOOK_SECRET="whsec_..."
supabase secrets set LIVIN_APP_URL="livin://payments"
supabase secrets set LIVIN_WEB_URL="https://YOUR_DOMAIN.com"
```

Deploy:

```bash
supabase functions deploy create-ticket-checkout
supabase functions deploy stripe-webhook
```

Call an Edge Function from the iOS app only after the user is signed in. The request needs the user's Supabase access token:

```swift
let url = URL(string: "\(supabaseURL)/functions/v1/create-ticket-checkout")!
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = try JSONEncoder().encode(["eventId": eventID, "quantity": 1])
```

Do not ship the Stripe secret key, Supabase service-role key, APNs `.p8`, Sentry auth token, PostHog project secret, or Resend secret in the app.

## 3. APNs Notifications

APNs needs both app setup and server setup.

### Apple Developer Setup

1. Enroll in the Apple Developer Program.
2. In Apple Developer portal, open Certificates, Identifiers & Profiles.
3. Create or open the App ID for bundle ID `vzn.LIVE`.
4. Enable Push Notifications.
5. In Xcode, select LIVE target > Signing & Capabilities.
6. Add `Push Notifications`.
7. Optional later: add `Background Modes` and check `Remote notifications`.

### APNs Key

1. Apple Developer portal > Keys.
2. Create key named `LIVIN APNs`.
3. Enable Apple Push Notifications service.
4. Download the `.p8` file once.
5. Save:
   - Team ID
   - Key ID
   - Bundle ID `vzn.LIVE`
   - `.p8` private key

Do not commit the `.p8` file.

Set APNs secrets in Supabase:

```bash
supabase secrets set APNS_TEAM_ID="YOUR_TEAM_ID"
supabase secrets set APNS_KEY_ID="YOUR_KEY_ID"
supabase secrets set APNS_BUNDLE_ID="vzn.LIVE"
supabase secrets set APNS_PRIVATE_KEY="$(cat /path/to/AuthKey_KEYID.p8)"
supabase secrets set APNS_ENVIRONMENT="sandbox"
```

Use `sandbox` for TestFlight/internal testing until production push is confirmed.

### App Flow

1. Ask notification permission after onboarding, not at first launch.
2. Register with APNs.
3. App receives a device token.
4. Save token to Supabase table `device_tokens`.
5. A server-side Edge Function sends pushes through APNs.

Device token insert shape:

```json
{
  "user_id": "auth.uid()",
  "token": "APNS_DEVICE_TOKEN",
  "platform": "ios",
  "environment": "sandbox"
}
```

MVP notification triggers:

- Friend follows you.
- Event you joined gets a new group message.
- Someone you follow posts a new public snap.
- Event you joined starts soon.

## 4. Maps, Places, and In-App Routes

The app currently uses MapKit:

- In-app snap map
- Zoom controls
- User location
- In-app route preview with ETA and distance
- Adaptive color overlay for a more Snapchat-style mood

This keeps cost low.

### Google Places for California Guide

Use Google Places when you want:

- Tourist spot suggestions
- Nearby places
- Search autocomplete
- Place photos and metadata
- Google place IDs for saved spots

Setup:

1. Go to Google Cloud Console.
2. Create project `livin-maps`.
3. Enable billing.
4. Enable:
   - Places SDK for iOS
   - Maps SDK for iOS, only if replacing MapKit map rendering
   - Routes API later, only if needed
5. Create an iOS API key.
6. Restrict the key:
   - Application restriction: iOS apps
   - Bundle ID: `vzn.LIVE`
   - API restriction: only the APIs you enabled
7. Add package dependency for Places:

```text
https://github.com/googlemaps/ios-places-sdk
```

MVP guide layer:

- Store curated California spots in `saved_places` or a new `guide_places` table.
- Render them as floating circles.
- Tapping a circle opens details.
- User can pin a guide spot to their folder.
- Avoid calling Places on every map pan. Cache results by city or region.

### Google Navigation

For real Google-level turn-by-turn inside L!V!N:

- Use Google Navigation SDK for iOS.
- It requires a Google Maps Platform project, billing, Navigation SDK enabled, and API key.
- It is the correct path for in-app navigation that feels like Google Maps.
- Use it after the first social MVP because navigation can become expensive and product-heavy.

For now:

- Keep MapKit route preview in-app.
- Add Google Places first.
- Add Google Navigation only once people actually use event routes.

## 5. Stripe Tickets

Keep all events free until the social loop works.

When ready:

- Use Stripe Connect because L!V!N is a marketplace if organizers sell tickets.
- Use Accounts v2 for new Connect accounts.
- Use destination charges so L!V!N can collect an application fee and transfer the rest to the organizer.
- Use Stripe-hosted onboarding for organizers.
- Use Stripe Checkout first because it is fastest and reduces PCI/payment UI risk.
- Move to PaymentSheet later only if the native checkout experience becomes important.

Do not process cards directly in the app.

### Stripe Setup

1. Create a Stripe account.
2. Stay in test mode.
3. In Developers > API keys, copy:
   - publishable key for the iOS app later
   - secret key for Supabase Edge Functions only
4. Keep the secret key server-side only.
5. Add Stripe iOS SDK later:

```text
https://github.com/stripe/stripe-ios
```

6. In Stripe Dashboard > Developers > Webhooks, create a webhook endpoint:

```text
https://YOUR_PROJECT.supabase.co/functions/v1/stripe-webhook
```

7. Subscribe to these events first:
   - `checkout.session.completed`
   - `checkout.session.expired`
   - `payment_intent.payment_failed`
   - `charge.refunded` later
   - `charge.dispute.created` later

8. Copy the webhook signing secret and save it as:

```bash
supabase secrets set STRIPE_WEBHOOK_SECRET="whsec_..."
```

9. Save the secret key:

```bash
supabase secrets set STRIPE_SECRET_KEY="sk_test_..."
```

10. Deploy the repo's starter functions:

```bash
supabase functions deploy create-ticket-checkout
supabase functions deploy stripe-webhook
```

### Stripe Connect Organizer Flow

Do this only after free events and identity work:

1. Host taps `Enable paid tickets`.
2. Server creates or retrieves the host's Stripe connected account.
3. Server creates a Stripe Account Link for hosted onboarding.
4. App opens the hosted onboarding link.
5. Stripe redirects back to the app/website.
6. A server refresh task stores:
   - `stripe_account_id`
   - `charges_enabled`
   - `payouts_enabled`
   - `details_submitted`

Store this in `stripe_connect_accounts`. Paid checkout should fail unless `charges_enabled = true`.

### Ticket Checkout Function

The starter function at `supabase/functions/create-ticket-checkout/index.ts` does this:

- checks that the user is signed in
- checks that the event exists
- checks that the event is paid
- checks that the organizer has a ready Stripe account
- creates a Stripe Checkout Session
- creates a pending `ticket_orders` row
- returns the Checkout URL

The app should show the Checkout URL in a secure web session. The database should not mark the ticket paid until the Stripe webhook confirms it.

### Webhook Function

The starter function at `supabase/functions/stripe-webhook/index.ts` does this:

- verifies the Stripe signature
- marks completed checkout sessions as `paid`
- inserts the buyer into `event_members`
- marks expired checkout sessions as `expired`

Before public paid tickets, add:

- capacity locking so tickets cannot oversell
- refunds
- organizer cancellation policy
- dispute handling
- tax/accounting review
- App Store policy review

## 6. Product Signals

Add signals before the friend/community TestFlight, not after, so feedback has data behind it.

### PostHog Analytics

Use PostHog for product behavior, feature flags, and funnels.

Setup:

1. Create a PostHog project.
2. Copy the project API key.
3. In Xcode, add Swift Package:

```text
https://github.com/PostHog/posthog-ios
```

4. Initialize after launch, ideally behind a privacy/consent decision:

```swift
import PostHog

let config = PostHogConfig(apiKey: "POSTHOG_PROJECT_API_KEY", host: "https://us.i.posthog.com")
PostHogSDK.shared.setup(config)
```

Track these first:

- `onboarding_completed`
- `events_opened`
- `event_expanded`
- `event_joined`
- `route_preview_opened`
- `map_opened`
- `snap_create_opened`
- `snap_posted`
- `profile_opened`
- `follow_tapped`
- `event_chat_message_sent`

Use feature flags for:

- event scroll variants
- map pin styles
- onboarding versions
- California guide layer

Do not track exact live location as analytics. Store exact location only where the product needs it, such as a snap/event coordinate, and protect it with privacy rules.

### Sentry Crashes

Use Sentry before external TestFlight.

Setup:

1. Create a Sentry iOS project.
2. Copy the DSN.
3. In Xcode, add Swift Package:

```text
https://github.com/getsentry/sentry-cocoa
```

4. Initialize in `LIVEApp.swift`:

```swift
import Sentry

SentrySDK.start { options in
    options.dsn = "YOUR_SENTRY_DSN"
    options.tracesSampleRate = 0.1
}
```

Track breadcrumbs for:

- camera permission failure
- location permission failure
- route calculation failure
- Supabase network failure
- storage upload failure
- checkout creation failure

### Resend Email

Use Resend for low-volume transactional email:

- waitlist confirmation
- TestFlight invite updates
- organizer verification messages
- support/contact replies

Setup:

1. Create a Resend account.
2. Add and verify your domain.
3. Create an API key.
4. Store it in Supabase:

```bash
supabase secrets set RESEND_API_KEY="re_..."
```

Send email from an Edge Function only. Do not call Resend directly from the iOS app.

## 7. Hostinger Website

I installed the Hostinger plugin, but this Codex thread does not currently expose a callable Hostinger website creation tool. What I can control from here:

- create and update website files in this repo
- match the app's visual style
- prepare files for Hostinger upload
- write deployment steps
- later connect forms to Supabase/Resend if you provide the destination

What you still do in Hostinger:

1. Open Hostinger hPanel.
2. Choose your domain or create a subdomain.
3. Open File Manager.
4. Upload the contents of `/Users/laptcv/Desktop/LIVE/website` into `public_html`.
5. Confirm:
   - `index.html`
   - `styles.css`
   - `assets/livin-icon.png`
6. Open the site in a private browser window.

Local preview:

```bash
cd /Users/laptcv/Desktop/LIVE/website
python3 -m http.server 8080
```

Then open:

```text
http://localhost:8080
```

## 8. TestFlight Plan

Before inviting friends:

1. Archive the app from Xcode.
2. Upload to App Store Connect.
3. Add internal testers first.
4. Add external testers after Apple beta review.
5. Make a feedback form with:
   - signup friction
   - event scroll feel
   - map usefulness
   - create snap clarity
   - privacy comfort
   - bugs/screenshots

TestFlight MVP acceptance:

- Two users can sign up.
- Two users can follow each other.
- User A can post a snap.
- User B can see it if allowed by privacy.
- Both can join one event.
- Event group chat updates live.
- Notification token saves.
- Route preview opens in-app.

## 9. Build Order

Recommended next build order:

1. Supabase package and config.
2. Auth screens and onboarding quiz.
3. Profile creation.
4. Events from database.
5. Join event writes to database.
6. Event group chat with Realtime.
7. Snap upload to Storage.
8. Snap map from database.
9. Follows and privacy RLS.
10. APNs token table and permission prompt.
11. California guide circles.
12. Stripe ticketing research, then implementation.

## 10. Dashboard Setup Order

Follow this exact order to keep costs and confusion down:

1. GitHub: confirm repo, branch, and PR workflow.
2. Apple Developer: confirm bundle ID `vzn.LIVE`, signing, TestFlight access, and APNs capability.
3. Supabase: create dev project, run SQL schema, enable Storage buckets, enable Realtime.
4. Xcode: add Supabase Swift package and app config.
5. App: implement auth, profile, onboarding, event join, snap upload, map read.
6. Supabase: deploy Edge Functions for signed media URLs and APNs token storage.
7. APNs: create `.p8` key and store Supabase secrets.
8. Sentry: add crash reporting before friends test.
9. PostHog: add analytics events and feature flags before community test.
10. Resend: verify domain and add waitlist/tester email function.
11. Hostinger: upload the static landing page.
12. Google Places: add billing-restricted key only when guide places need live search.
13. Stripe: keep in test mode; wire Connect/Checkout only after free events work.

## 11. Secret Checklist

Never commit these:

- Supabase service-role key
- Stripe secret key
- Stripe webhook secret
- APNs `.p8` file contents
- Resend API key
- Sentry auth token
- Google unrestricted API keys

Allowed in the iOS app:

- Supabase URL
- Supabase publishable/anon key
- Stripe publishable key, later
- Sentry DSN
- PostHog project API key
- Google iOS-restricted API key

Prefer separate values for:

- `dev`
- `testflight`
- `prod`

## 12. What Is Already Done In This Repo

- Native SwiftUI prototype.
- L!V!N branding with app code still named `LIVE`.
- Events tab with fixed-gap manual vertical scroll.
- Tap event to expand details; tap details/close to collapse.
- Map tab with snap pins and zoom controls.
- Create snap outline.
- Profile privacy mode outline.
- Setup docs and stack recommendation.
- Supabase/Stripe Edge Function starter files.
- Hostinger-ready static landing page.

## 13. What Still Requires Your Dashboard Access

I cannot finish these without your private accounts/keys:

- creating the Supabase project
- pasting Supabase project URL/key into app config
- running SQL in Supabase SQL Editor
- creating Apple APNs key
- uploading an app archive to App Store Connect
- creating Stripe account/webhook signing secret
- completing Stripe Connect platform settings
- creating Google Cloud billing/API keys
- verifying Resend domain DNS
- uploading website files into Hostinger hPanel
