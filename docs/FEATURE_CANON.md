# ChronoSpark Feature Canon

Status: authoritative product-language and route contract.

ChronoSpark is an evidence-aware personal operating system: it turns what
matters into one explainable next decision, records the outcome, adapts the
plan, and shows how each choice changes the user's trajectory. Feature copy
must reinforce that operating loop instead of presenting a generic planner,
habit tracker, dashboard, or chat wrapper.

| Canonical surface | Purpose | Canonical route |
| --- | --- | --- |
| Nexus | Converges all evidence into the next accountable decision | `/nexus` |
| Smart Planner | Reconciles competing commitments into an executable plan | `/smart-planner` |
| Creator | Creates connected commitments and context with downstream impact receipts | `/creator` |
| SI Console | Investigates recommendation evidence, uncertainty, alternatives, and consequences | `/si-console` |
| Timeline | Records the causal execution history that teaches the system | `/timeline` |
| Trajectory Engine | Compares explicit future paths, assumptions, and corrections | `/trajectory` |
| Progression | Proves behavioral change, reliability, recovery, and gained capability | `/progression` |

## Rules

- Use canonical names in all new UI copy, routes, documentation, analytics labels, and support material.
- Calendar, tasks, habits, goals, and notes are Creator-owned inputs. Timeline is their scheduling projection, not a second authoring surface.
- Product `Session` and `Focus` are removed. Authentication-session terminology remains valid only for account lifecycle code.
- `Insight` is not a product surface. It may appear only as an output from Smart Planner or SI Console.
- `Flowmap` is not a product surface.
- Use `Reflection` for reflective records. Deprecated storage spelling may be
  decoded only inside a compatibility adapter and must never become an active
  symbol, route, analytic, or user-visible label.
- Internal legacy class and file names are not product vocabulary; do not expose them in new copy or routes.
- Historical data adapters may retain deprecated storage keys only when clearly marked compatibility-only and unreachable from product UI.

## Compatibility

Legacy deep links are preserved only through explicit redirects in `lib/app/router/app_router.dart`. New links must target the canonical routes above. Every compatibility alias needs a sunset owner and date in `docs/LEGACY_ROUTE_SUNSET.md` before it can be removed.
