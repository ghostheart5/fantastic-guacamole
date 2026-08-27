# ChronoSpark Feature Canon

Status: authoritative product-language and route contract.

ChronoSpark is an evidence-aware decision intelligence system: it turns what
matters into one explainable next decision, records the outcome, adapts the
plan, and shows how each choice changes the user's trajectory. Feature copy
must reinforce that decision loop instead of presenting a generic planner,
habit tracker, dashboard, or chat wrapper.

| Primary canon feature | Purpose | Canonical route |
| --- | --- | --- |
| Nexus | Converges all evidence into the next accountable decision | `/nexus` |
| Smart Planner | Reconciles competing commitments into an executable plan | `/smart-planner` |
| Creator | Creates connected commitments and context with downstream impact receipts | `/creator` |
| Settings | Owns preferences, account controls, privacy, and support | `/settings` |
| Timeline | Records the causal execution history that teaches the system | `/timeline` |
| Trajectory Engine | Compares explicit future paths, assumptions, and corrections | `/trajectory` |

## Support surfaces

| Support surface | Parent workflow | Route |
| --- | --- | --- |
| Profile | Identity, preferences, and progression context | `/settings/advanced/profile` |
| Progression | Evidence-backed advancement and leverage actions | `/settings/advanced/progression` |
| SI Console | Advanced strategic investigation and guidance | `/settings/advanced/si-console` |
| Notifications | Settings-owned reminders and alerts | `/settings/notifications` |
| Subscriptions | Account and billing support | `/paywall` |

## Evidence sources and outputs

Insights, signals, forecasts, recommendations, and activity summaries are outputs shown inside a canon feature. They are not destination-level product promises.

## Diagnostics and internal tools

Product Advisor is an internal/admin diagnostic surface. It may help developers, QA leads, and product administrators inspect product health, optimizer state, and generated findings, but it is not a production-facing premium feature or tester-facing product capability. Access requires a trusted Supabase auth app-metadata claim; premium access, tester access, mock login, and user-editable metadata do not grant Product Advisor access.

## Rules

- Use canonical names in all new UI copy, routes, documentation, analytics labels, and support material.
- Calendar, tasks, habits, goals, and notes are Creator-owned inputs. Timeline is their scheduling projection, not a second authoring surface.
- Product `Session` and `Focus` are removed. Authentication-session terminology remains valid only for account lifecycle code.
- `Insight` and `Signal` are not product surfaces. They may appear only as contextual outputs inside a canon feature.
- `Flowmap` is internal architecture documentation, not a product surface.
- Use `Reflection` for reflective records. Deprecated storage spelling may be
  decoded only inside a compatibility adapter and must never become an active
  symbol, route, analytic, or user-visible label.
- Internal legacy class and file names are not product vocabulary; do not expose them in new copy or routes.
- Historical data adapters may retain deprecated storage keys only when clearly marked compatibility-only and unreachable from product UI.

## Compatibility

Legacy deep links are preserved only through explicit redirects in `lib/app/router/app_router.dart`. New links must target the canonical routes above. Every compatibility alias needs a sunset owner and date in `docs/LEGACY_ROUTE_SUNSET.md` before it can be removed.
