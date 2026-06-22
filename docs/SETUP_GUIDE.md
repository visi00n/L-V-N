# L!V!N Setup Guide

This guide is the practical setup path for turning the local prototype into a real multiplayer TestFlight app while keeping costs low.

Official docs used:

- GitHub repository setup: https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository
- GitHub remotes: https://docs.github.com/en/get-started/git-basics/about-remote-repositories
- Supabase iOS SwiftUI quickstart: https://supabase.com/docs/guides/getting-started/quickstarts/ios-swiftui
- Supabase Swift reference: https://supabase.com/docs/reference/swift/introduction
- Supabase RLS: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase Realtime: https://supabase.com/docs/guides/realtime
- Supabase Storage access control: https://supabase.com/docs/guides/storage/security/access-control
- Apple APNs registration: https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns
- Google Maps SDK for iOS: https://developers.google.com/maps/documentation/ios-sdk
- Google Places SDK for iOS: https://developers.google.com/maps/documentation/places/ios-sdk/overview
- Google Navigation SDK for iOS: https://developers.google.com/maps/documentation/navigation/ios-sdk
- Stripe iOS payments: https://docs.stripe.com/payments/accept-a-payment?payment-ui=mobile&platform=ios
- Stripe Connect Accounts v2: https://docs.stripe.com/connect/accounts-v2

## Cost Strategy

Start with:

- GitHub private repo: free for the prototype.
- Supabase Free: enough to validate auth, profiles, events, snaps, chat, and storage with a small tester group.
- Apple Developer Program: required for TestFlight and APNs, currently 99 USD per membership year in the US.
- MapKit first: already in the app, no Google bill for the MVP route preview.
- Google Maps/Places later: enable billing but restrict keys. Use Places only for guide spot discovery and saved place metadata at first.
- Stripe later: keep events free until auth, database, moderation, refunds, and organizer trust are ready.

Do not add paid tickets to the first TestFlight build. Ship social proof first: account, snap map, event signup, event group chat, profiles, follows, and notifications.

## 1. GitHub Setup

Current local status:

- GitHub CLI is installed.
- The machine is authenticated as `visi00n`.
- This local repo has no `origin` remote yet.

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
  creator_id uuid not null references public.profiles(id) on delete cascade,
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

alter table public.profiles enable row level security;
alter table public.follows enable row level security;
alter table public.events enable row level security;
alter table public.event_members enable row level security;
alter table public.snaps enable row level security;
alter table public.snap_media enable row level security;
alter table public.event_messages enable row level security;
alter table public.saved_places enable row level security;
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
    where p.id = snaps.creator_id
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
with check (creator_id = auth.uid());

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
```

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

### App Flow

1. Ask notification permission after onboarding, not at first launch.
2. Register with APNs.
3. App receives a device token.
4. Save token to Supabase table `device_tokens`.
5. A server-side Edge Function sends pushes through APNs.

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
- Use Stripe PaymentSheet or Checkout from the iOS app.

Do not process cards directly in the app.

### Stripe Setup

1. Create a Stripe account.
2. Stay in test mode.
3. In Developers > API keys, copy test publishable key.
4. Keep secret key server-side only.
5. Add Stripe iOS SDK later:

```text
https://github.com/stripe/stripe-ios
```

6. Create a backend Edge Function:
   - `create-ticket-checkout`
   - validates event exists
   - validates event is paid
   - validates ticket availability
   - creates a Checkout Session or PaymentIntent
   - sets platform application fee
   - records pending ticket order

7. Create webhook handler:
   - `checkout.session.completed`
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
   - refunds and disputes later

### Ticketing Tables Later

```sql
create table public.ticket_orders (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  stripe_checkout_session_id text,
  stripe_payment_intent_id text,
  amount_cents integer not null,
  platform_fee_cents integer not null,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);
```

## 6. TestFlight Plan

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

## 7. Build Order

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
