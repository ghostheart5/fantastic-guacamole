# Route Surfaces Policy

Primary surfaces should stay minimal and map to the current product canon:

- Nexus (home): `/home`
- Smart Planner: `/plan`
- Creator: `/creator`
- Settings: `/settings`

Secondary/advanced surfaces should be nested under settings paths:

- `/settings/notifications`
- `/settings/advanced/*` (Timeline/ledger, tasks, profile, Progression, SI Console)

Legacy compatibility:

Old top-level routes (including `/coach`, `/signals`, `/logs`, `/si`, and `/tasks`) are maintained only as compatibility redirects and must not be used for new links. `/signals` redirects to Smart Planner; Signal is an output, not a standalone surface.

Implementation reference:

- `lib/app/router/route_paths.dart`
- `lib/app/router/app_router.dart`
