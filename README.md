# L!V!N

L!V!N is a live-map social app prototype for finding events, going outside, posting location-locked snaps, and building a personal map of places and people.

The app-facing brand is `L!V!N`. The Xcode target, bundle code paths, and Swift symbols intentionally remain `LIVE` for now so the project stays easy to build and refactor.

## Current Prototype

- Events tab with manual vertical scrolling and haptic selection ticks.
- Tap an event card to expand details; tap the expanded card again to close it.
- Map tab for location-based snaps and profile/map memory previews.
- Create flow for camera/photo-backed live snaps.
- Profile settings for public/private account mode.

## Next Build Priorities

1. Multiplayer backend: accounts, profiles, posts, event joins, group chats, realtime updates.
2. TestFlight friend testing: two users should be able to see each other's posts/profiles and chat inside joined events.
3. Onboarding quiz: interests, area type, privacy defaults, event radius, tourist/local mode.
4. California guide map: saved Google Maps-style places, floating place circles, save-to-folder pins.
5. Ticketing: free events by default, optional paid tickets later with platform fee.

See [docs/PRODUCT_ROADMAP.md](docs/PRODUCT_ROADMAP.md) for the implementation plan, [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md) for service setup, and [docs/TECH_STACK_RECOMMENDATION.md](docs/TECH_STACK_RECOMMENDATION.md) for the current stack decision.
