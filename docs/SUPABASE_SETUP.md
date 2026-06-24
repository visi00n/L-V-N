# L!V!N Supabase Setup

Use this as the current source of truth for the Supabase MVP setup.

## Project Values

- Supabase project ref: `wppernaddlrwjgcmikyj`
- Supabase dashboard: https://supabase.com/dashboard/project/wppernaddlrwjgcmikyj
- Swift app project URL: `https://wppernaddlrwjgcmikyj.supabase.co`
- Data API URL shown in Supabase: `https://wppernaddlrwjgcmikyj.supabase.co/rest/v1/`
- iOS publishable key: stored in `LIVE/LiveConfig.swift`

Use the base project URL in Swift, not the `/rest/v1/` URL. The `/rest/v1/` address is the REST API endpoint; the Supabase Swift client builds Auth, Storage, Realtime, and database URLs from the base URL.

Never put these in the iOS app:

- `service_role` key
- database password
- JWT secret
- Stripe secret key
- APNs `.p8` private key
- Resend secret key

## What I Already Added In Xcode

The Supabase Swift package is already connected to the `LIVE` app target.

- Package: `https://github.com/supabase/supabase-swift`
- Product: `Supabase`
- Resolved version: `2.48.0`
- Config file: `LIVE/LiveConfig.swift`
- Shared client: `LIVE/SupabaseService.swift`

You can still see it in Xcode:

1. Open `/Users/laptcv/Desktop/LIVE/LIVE.xcodeproj`.
2. Click the blue project icon at the top of the navigator.
3. Select the `LIVE` project.
4. Open the `Package Dependencies` tab.
5. Confirm `supabase-swift` is listed.
6. Select the `LIVE` target.
7. Open `General`.
8. Under `Frameworks, Libraries, and Embedded Content`, confirm `Supabase` is listed.

If you ever need to add it manually again:

1. Xcode > File > Add Package Dependencies.
2. Paste `https://github.com/supabase/supabase-swift`.
3. Add the `Supabase` product to the `LIVE` target.

## Dashboard Navigation

Open the Supabase dashboard:

```text
https://supabase.com/dashboard/project/wppernaddlrwjgcmikyj
```

If that link does not open directly:

1. Go to https://supabase.com/dashboard.
2. Sign in.
3. Click the L!V!N project.
4. If you do not see it, check that you are in the right Supabase organization/workspace.

## Auth Setup

1. In the left sidebar, click `Authentication`.
2. Click `Providers`.
3. Enable `Email`.
4. For MVP, keep email/password or magic link simple.
5. Later, add Apple Sign In before a serious TestFlight round.

Also check:

1. Authentication > URL Configuration.
2. Add app/web redirect URLs later when we implement auth callback flow.
3. Do not worry about this until the first real login screen is being connected.

## SQL Editor

The SQL Editor is where you run the schema and policies.

1. In the Supabase left sidebar, click `SQL Editor`.
2. Click `New query`.
3. Paste one SQL file at a time.
4. Click `Run`.

If you do not see `SQL Editor`, use the dashboard search:

```text
SQL Editor
```

Run these in order:

1. `/Users/laptcv/Desktop/LIVE/supabase/schema.sql`
2. `/Users/laptcv/Desktop/LIVE/supabase/rls_policies.sql`
3. Create storage buckets in the UI.
4. `/Users/laptcv/Desktop/LIVE/supabase/storage_policies.sql`
5. Enable realtime in the UI, or run `/Users/laptcv/Desktop/LIVE/supabase/realtime_tables.sql`.

If a query says a policy already exists, it usually means that policy was already run. Do not keep clicking Run repeatedly. Either skip it or drop the old policy first once we know exactly what changed.

## Schema

Run:

```text
/Users/laptcv/Desktop/LIVE/supabase/schema.sql
```

This creates the MVP tables:

- `profiles`
- `follows`
- `events`
- `event_members`
- `event_messages`
- `snaps`
- `snap_media`
- `direct_conversations`
- `direct_conversation_members`
- `direct_messages`
- `reports`
- `device_tokens`

It also enables RLS and adds indexes for the main foreign keys, chat ordering, profile privacy checks, snap lookups, and device token lookups.

## RLS Policies

Run:

```text
/Users/laptcv/Desktop/LIVE/supabase/rls_policies.sql
```

These policies cover:

- public/private profile reads
- users creating and updating their own profile
- follows
- event reads and host updates
- event membership
- event group chat
- public/friends/own snap visibility
- snap media metadata
- direct message reads/sends by conversation members
- reports
- device token ownership

This is still MVP security. Before public launch, we should do a full RLS review with test users for private accounts, blocked users, deleted users, moderation, and media URL access.

## Storage Buckets

Create the buckets in the dashboard:

1. Left sidebar > `Storage`.
2. Click `New bucket`.
3. Create `snap-media`.
4. Set `snap-media` to `Private`.
5. Click `New bucket`.
6. Create `avatars`.
7. Set `avatars` to `Public` for MVP.

Then run:

```text
/Users/laptcv/Desktop/LIVE/supabase/storage_policies.sql
```

MVP behavior:

- signed-in users can upload snap media they own
- signed-in users can read `snap-media`
- users can update/delete their own snap media
- signed-in users can upload avatars they own
- avatars can be read publicly

The `snap-media` read policy is intentionally simple so the prototype works quickly. Before a public launch, tighten this by serving private snap media through a Supabase Edge Function that checks `snaps` visibility and returns signed URLs only to allowed viewers.

## Realtime

Dashboard route:

1. Left sidebar > `Database`.
2. Find `Replication` or `Publications`.
3. Open the `supabase_realtime` publication.
4. Enable these tables:
   - `snaps`
   - `events`
   - `event_members`
   - `event_messages`
   - `direct_messages`
   - `follows`

If you prefer SQL, run:

```text
/Users/laptcv/Desktop/LIVE/supabase/realtime_tables.sql
```

Use Postgres Changes for the MVP:

- snap map updates
- event changes
- event member counts
- event chat
- direct messages
- follows

Presence can come later for `who is here` and `who is online`.

## First App Connection Check

The app now has:

```swift
let supabase = SupabaseClient(
    supabaseURL: LiveConfig.supabaseURL,
    supabaseKey: LiveConfig.supabasePublishableKey
)
```

The local compile check passed:

```bash
xcodebuild -project LIVE.xcodeproj -scheme LIVE -configuration Debug -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

Next coding step:

1. Add auth screens.
2. Create a profile row after signup.
3. Connect event list reads.
4. Connect snap upload to `snap-media`.
5. Subscribe to realtime table changes.

## Minimal Test Data

After auth works, create real records from the app instead of manually inserting users. Supabase Auth owns `auth.users`, and `profiles.id` must match an Auth user id.

For fake event rows, use a real signed-in user's profile id as `host_id`. Do not invent random host ids unless a matching `profiles` row exists.

## Troubleshooting

If Swift says `No such module 'Supabase'`:

1. In Xcode, open Package Dependencies.
2. Confirm `supabase-swift` is present.
3. Product must be attached to the `LIVE` target.
4. Run File > Packages > Resolve Package Versions.

If SQL says `permission denied`:

1. Make sure you are running SQL inside the project dashboard SQL Editor.
2. Make sure you are not using the client app key to run admin SQL.

If Storage uploads fail:

1. Confirm the bucket exists.
2. Confirm the bucket name matches exactly: `snap-media` or `avatars`.
3. Confirm the user is authenticated.
4. Confirm the storage policy has run.

If Realtime does not fire:

1. Confirm the table is in the `supabase_realtime` publication.
2. Confirm RLS allows the signed-in user to read that row.
3. Test with a simple `snaps` insert first.
