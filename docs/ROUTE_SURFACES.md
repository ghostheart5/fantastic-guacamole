# Route Surfaces Policy

Primary surfaces should stay minimal and map to the main product loop:

- Now: `/home`
- Plan: `/plan`
- Add: `/creator`
- Reflect: `/insights`
- Settings: `/settings`

Secondary/advanced surfaces should be nested under settings paths:

- `/settings/notifications`
- `/settings/advanced/*` (logs, tasks, profile, progression, si-console)

Legacy compatibility:

Old top-level routes (for example `/logs`, `/si`, `/tasks`) are maintained only as redirects in the router and should not be used for new links.

Implementation reference:

- `lib/app/router/route_paths.dart`
- `lib/app/router/app_router.dart`
