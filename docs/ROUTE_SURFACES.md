# Route Surfaces Policy

Primary canon features should stay minimal and map to the current product canon:

- Nexus (home): `/nexus`
- Smart Planner: `/smart-planner`
- Creator: `/creator`
- Timeline: `/timeline`
- Trajectory Engine: `/trajectory`
- Settings: `/settings`

Support surfaces are important, but subordinate to a canon feature or advanced workflow:

- `/settings/notifications`
- `/settings/advanced/*` (profile, Progression, SI Console, internal diagnostics)
- `/paywall`

Evidence sources and outputs:

- Insights, signals, forecasts, recommendations, and activity summaries may appear inside feature content.
- They must not become destination-level product promises or navigation labels.

Legacy compatibility:

Old top-level routes (including `/coach`, `/insights`, `/logs`, `/plan`, `/si`, and `/tasks`) are maintained only as compatibility redirects and must not be used for new links. `/insights` redirects to Smart Planner; insight is an output, not a standalone surface.

Diagnostics and internal tools:

- Product Advisor, completion-event views, debug/admin routes, and FlowMaps are internal/admin/QA surfaces.
- Product Advisor must remain admin-gated and must not be presented as a premium feature promise.

Implementation reference:

- `lib/app/router/route_paths.dart`
- `lib/app/router/app_router.dart`
