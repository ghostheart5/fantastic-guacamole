# Route Access Policy

Status: Phase 1 route-access contract.

This document classifies every route in `lib/app/router/route_paths.dart`.
Routes must be evaluated by class instead of using one global authentication
rule for all paths.

## Decisions

| Access class | Routes | Decision | Confirmation status |
| --- | --- | --- | --- |
| Welcome | `/onboarding` | May gate normal app entry and normal login. Must not interrupt authentication callback modes on `/login`. | Confirmed by product/security policy. |
| Authentication | `/login`, `/login?mode=recovery`, `/login?mode=verify-email`, `/login?mode=auth-callback` | Signed-out access allowed. Recovery, verification, and auth-callback modes must remain reachable even when welcome/profile setup is incomplete. | Confirmed by product/security policy. |
| Public information | `/privacy`, `/terms`, `/support`, `/about` | Signed-out access allowed. These pages must work before account creation and before onboarding completion. | Product/legal policy confirmed for implementation; external legal review remains a release-signoff item. |
| Account-sensitive information | `/delete-account` | Signed-out access allowed for deletion instructions only. Any destructive account deletion action remains authenticated in the backend/support flow. | Product/legal/security policy confirmed for implementation; external legal review remains a release-signoff item. |
| Protected application | `/`, `/home`, `/nexus`, `/creator`, `/settings`, `/settings/notifications`, `/settings/advanced/logs`, `/settings/advanced/tasks`, `/settings/advanced/profile`, `/settings/advanced/progression`, `/settings/advanced/si-console`, `/timeline`, `/smart-planner`, `/trajectory`, `/plan`, `/logs`, `/notifications`, `/progression`, `/si`, `/tasks`, `/profile`, `/coach`, `/signals`, `/insights`, unknown paths | Requires welcome complete, authentication, and completed onboarding/profile setup. Legacy routes are compatibility redirects only after access checks pass. Unknown paths fail closed behind the same app gates. | Confirmed by product/security policy. |
| Commercial | `/paywall` | Requires welcome complete and authentication. Completed onboarding/profile setup is not required because purchases, restoration, and entitlement checks are account-bound but may occur before full app setup. | Confirmed by product/security policy. |
| Privileged internal | `/settings/advanced/advisor` | Requires welcome complete, authentication, completed onboarding/profile setup, a debug/developer build, and a trusted internal-advisor claim from Supabase auth app metadata. Release builds redirect to Settings. Product Advisor is internal diagnostics, not a production-facing premium feature or tester-facing product capability. | Confirmed by product/security policy. |

## Implementation reference

- `lib/app/router/route_access_policy.dart`
- `lib/app/router/app_router.dart`
- `test/app/app_redirect_fuzz_test.dart`

## Callback and return-destination policy

- Redirect evaluation must receive the full `Uri`, not only the matched path.
- Authentication callbacks are recognized only through allowlisted modes:
  - `mode=recovery`
  - `mode=verify-email`
  - `mode=auth-callback`
- Signed-out callback URLs must reach the authentication UI even when welcome or
  profile setup is incomplete.
- Once authentication is present, callback URLs resume a validated return
  destination or fall back to `/nexus`.
- Protected-route redirects may carry `returnTo`, but only for known internal
  app paths.
- `returnTo` rejects absolute URLs, external authorities, relative paths,
  malformed values, recursive destinations, unknown paths, and privileged
  internal diagnostics.
- Accepted return destinations preserve their query string and fragment.
- Deep-link handling must not mark a link handled until the router accepts the
  resolved internal target.

## Release signoff notes

- The implementation policy intentionally makes public legal/support pages
  reachable while signed out.
- `/delete-account` exposes instructions publicly; destructive deletion must
  remain authenticated outside this page.
- Product Advisor must not be used in navigation, onboarding, paywall copy, or
  tester-facing product promises.
- Product Advisor authorization must derive only from trusted Supabase
  `app_metadata` claims such as `chronospark_admin: true` or an approved
  internal role in `chronospark_roles` / `roles`. User-editable metadata,
  premium entitlement, tester-full-access, mock login, and local flags are not
  authorization evidence.
