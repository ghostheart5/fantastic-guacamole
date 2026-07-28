# Testability blockers

This file documents areas that cannot be exercised safely without app-side changes.

- File: lib/app/startup/app_bootstrap.dart
  - Class/provider/service: AppBootstrapper
  - Why it cannot be tested safely: it wires runtime plugins and startup services directly, making it hard to isolate without modifying bootstrapping code.
  - Minimal future fix: expose a small injectable startup dependency graph and a test-friendly bootstrap entrypoint.

- File: lib/features/auth/ui/login_screen.dart
  - Class/provider/service: LoginScreen
  - Why it cannot be tested safely: it relies on platform assets, animations, and MediaQuery-driven layout behavior that makes unit testing brittle without a widget harness refactor.
  - Minimal future fix: extract the form sub-tree into a testable stateless widget with a smaller dependency surface.
