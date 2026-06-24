# L!V!N TestFlight Checklist

## Before Upload

- Use a unique bundle identifier in Xcode under Signing & Capabilities.
- Keep automatic signing enabled with your Apple Developer team.
- Confirm camera, photo library, and location privacy strings are present.
- Set version/build numbers before each upload.
- Add a real App Icon before external testing.
- Confirm the display name is `L!V!N` while code/project identifiers can remain `LIVE`.
- App encryption answer for the current prototype: `None of the algorithms mentioned above`.
- Confirm `ITSAppUsesNonExemptEncryption` is set to `NO` unless future code adds custom/non-Apple encryption.
- Run the app on at least one real iPhone before submitting to TestFlight.

## First Community Test

- Start with 10-25 trusted testers.
- Ask testers to try: event wheel scroll, event details, route button, map zoom, create snap camera, attaching a snap to an event, profile/settings.
- Collect feedback on: confusion points, crashes, map accuracy, event card readability, and whether the app actually makes them want to go outside.
- Keep the first test invite text simple: what L!V!N is, what to try, and where to send feedback.

## Real App Requirements

- Accounts and auth.
- Backend database for events, snaps, follows, groups, and privacy.
- Real media upload/storage with compression.
- Location verification for live snaps.
- Push notifications.
- Supabase project, RLS policies, Realtime, and Storage buckets.
- APNs device-token table and notification sender.
- Reporting, moderation, blocking, and private account rules.
- Event payments and organizer controls.
- Analytics for activation, event joins, snap creation, retention, and reports.
