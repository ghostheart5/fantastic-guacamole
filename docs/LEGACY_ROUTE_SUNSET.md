# Legacy Route Sunset

Legacy route redirects in `lib/app/router/app_router.dart` exist only to preserve older deep links and bookmarks while the app moves to the consolidated navigation model.

## Current Legacy Routes

- `/coach`
- `/logs`
- `/notifications`
- `/progression`
- `/si`
- `/tasks`
- `/profile`

## Sunset Plan

- Keep redirects through the next stable migration window.
- Target review date: `2026-10-01`.
- Remove the redirects after one release cycle with no reported legacy-link dependence from QA, support, or store-distributed builds.

If new legacy routes are added, they must include an explicit sunset date and migration rationale.
