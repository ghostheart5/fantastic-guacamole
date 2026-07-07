# Barrel Boundaries

Barrel files are allowed, but they must stay inside their own architecture layer.

Enforced barrel boundaries:

- `lib/domain/domain.dart` -> may only export `package:fantastic_guacamole/domain/*`
- `lib/state/providers/providers.dart` -> may only export `package:fantastic_guacamole/state/*`
- `lib/state/controllers/controllers.dart` -> may only export `package:fantastic_guacamole/state/*`
- `lib/ui/widgets/widgets.dart` -> may only export `package:fantastic_guacamole/ui/*`
- `lib/theme/theme.dart` -> may only export `package:fantastic_guacamole/theme/*`

Why:

- Prevent accidental cross-layer coupling through a convenient import.
- Keep dependency direction explicit and predictable.

Guardrail:

- Enforced in `check_architecture.ps1` (Rule 9).
- Run with VS Code task: `check-architecture`.
