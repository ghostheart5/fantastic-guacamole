# ChronoSpark Layer Flow

This is the required dependency direction for the app:

```mermaid
flowchart TD
  UI[UI (features)] --> STATE[Riverpod providers (state)]
  STATE --> REPO[Repositories (data/di)]
  REPO --> SERVICES[Services (Supabase / storage)]
  SERVICES --> ENGINE[Engine (logic layer)]
```

## Rule

Dependencies only go downward in this order. Lower layers must not import upper layers.

## Layer responsibilities

- UI (features): Rendering, user interactions, navigation, and presentation-only formatting.
- Riverpod providers (state): View state, orchestration, and use-case style coordination for screens.
- Repositories (data/di): Data access abstraction and composition over services.
- Services (Supabase / storage): External systems, persistence, auth, network, and device APIs.
- Engine (logic layer): Pure decision logic and scoring; deterministic business intelligence where possible.

## Anti-patterns to avoid

- UI importing service classes directly.
- State providers calling storage/network directly without a repository.
- Engine depending on Flutter UI or widget classes.
- Repositories importing feature widgets or screens.

## Practical wiring pattern

1. UI watches providers and dispatches intents.
2. Providers call repositories.
3. Repositories use services.
4. Services return raw or mapped data.
5. Providers update state and UI re-renders.
