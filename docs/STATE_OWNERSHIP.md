# State Ownership Rule

Application state in this repository is centralized.

Rule:
- Riverpod providers that represent application/business state must live in `lib/state/providers`.
- Feature folders (`lib/features/*`) should contain UI/widgets and feature-local pure helpers only.
- Do not declare application providers inside feature files.

Allowed in features:
- Stateless/Stateful widgets
- Pure formatting/validation helpers
- Feature-specific UI mappers that do not own app state

Not allowed in features:
- `final ...Provider = Provider<...>` declarations for app state
- Feature-local repositories/services that duplicate global ownership

Guardrail:
- Enforced by `check_architecture.ps1` (Rule 8).
- Run via VS Code task: `check-architecture`.
