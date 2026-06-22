# L!V!N Product Roadmap

## Direction

Build L!V!N as a social map first, not a normal feed. The map becomes the feed: live snaps are floating post squares, guide spots are floating circles, and events are the reason people meet up.

## Multiplayer Plan

Recommended stack for the first real TestFlight multiplayer build:

- Auth: Supabase Auth with Apple sign-in and phone/email fallback.
- Database: Supabase Postgres for profiles, events, joins, snaps, follows, saved places, and chats.
- Realtime: Supabase Realtime channels for event group chat and new snap updates.
- Storage: Supabase Storage for snap media thumbnails/full images.
- Push: Apple Push Notifications for event chat, friend posts, and nearby event alerts.
- Moderation: server-side image/text moderation before public map visibility.

Core tables:

- `profiles`: user identity, handle, privacy mode, interests, home region.
- `follows`: follower/following graph.
- `events`: title, host, location, start time, capacity, ticket mode.
- `event_members`: joined users and RSVP state.
- `snaps`: creator, coordinate, caption, media URLs, event attachment, privacy.
- `chat_messages`: event-scoped group chat messages.
- `saved_places`: user pins and folders.
- `guide_places`: curated California places and metadata.

## TestFlight Multiplayer Milestone

The first friend-test should prove:

- Two real accounts can sign in.
- Each user can create/update a profile.
- User A can create a snap and User B can see it on the map.
- Both users can join the same event.
- Joined users can send messages in that event group chat.
- Public/private account mode changes who can see snaps.

## Events And Ticketing

Default all events to free. Later, add paid event support:

- Host chooses `Free` or `Ticketed`.
- Ticketed events use Stripe Checkout or PaymentSheet.
- Platform fee is configured server-side.
- Payouts require Stripe Connect if L!V!N pays hosts.
- Event access is unlocked only after successful payment webhook.

Do not ship paid tickets until backend auth, event ownership, refunds, fraud controls, and App Store payment policy review are handled.

## Onboarding Quiz

First version questions:

- Local, tourist, or new-in-town?
- Favorite activities: sports, outdoors, food, music, art, nightlife, study, volunteering.
- Preferred radius.
- Public or private account.
- Notification intensity.
- Comfort zone goal: chill, social, adventurous.

Onboarding should produce recommendation inputs, not a long personality test.

## California Guide Map

Start with curated California places:

- Beaches, hikes, viewpoints, cafes, museums, courts, bookstores, nightlife, study spots.
- Places appear as floating circles on the map.
- Live snaps appear as floating squares.
- Users can pin guide places into folders on their profile map.

Google Maps integration options:

- Use Google Places API for place search/details/photos.
- Use Google Maps URLs for external navigation if staying on Apple Map UI.
- Full Google Maps SDK can come later if Apple Map styling becomes a blocker.

## GitHub Workflow

Use GitHub issues for each update:

- `prototype`: local UI/demo work.
- `backend`: multiplayer, auth, storage, realtime.
- `maps`: guide places, saved pins, location features.
- `monetization`: tickets, fees, payouts.
- `testflight`: signing, archives, release notes, tester feedback.

Keep each update small enough to test on a phone.
