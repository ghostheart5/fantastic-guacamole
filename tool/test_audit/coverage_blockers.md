# Coverage blockers

These areas were not expanded in this pass because they require runtime/plugin bootstrapping or integration wiring that is not safe for deterministic unit/widget tests.

- lib/app/startup/app_bootstrap.dart
  - Blocker: startup path initializes Firebase, notifications, deep links, and platform messaging.
  - Needed for tests: injectable boot delegates or a pure startup planner.

- lib/features/nexus/ui/nexus_screen.dart
  - Blocker: depends on broad provider graph and app shell runtime state.
  - Needed for tests: extracted presentational widget with explicit view-model input.

- lib/features/creator/ui/creator_screen.dart
  - Blocker: depends on live provider composition, generated forms, and app navigation wiring.
  - Needed for tests: smaller composable widgets with injectable callbacks.

- lib/features/timeline/ui/timeline_screen.dart
  - Blocker: large provider fan-in and domain/usecase orchestration.
  - Needed for tests: test-only fixture provider bundle or split into pure presenter logic.

- lib/features/profile/ui/profile_screen.dart
  - Blocker: screen composition relies on app-level provider state and feature flags.
  - Needed for tests: scoped view model contract that can be injected.

- lib/features/settings/ui/settings_screen.dart
  - Blocker: notification permissions and platform-specific integration flows.
  - Needed for tests: permission gateway abstraction override in widget tests.

- lib/features/progression/ui/progression_screen.dart
  - Blocker: screen depends on aggregated providers and runtime state.
  - Needed for tests: pure summary widget entry points with explicit inputs.

- lib/features/trajectory_engine/ui/trajectory_engine_screen.dart
  - Blocker: feature wiring relies on provider graph and derived prediction providers.
  - Needed for tests: extracted prediction presenter with fake model input.

- lib/features/si_console/ui/si_console_screen.dart
  - Blocker: command pipeline and AI/service integration paths are not isolated.
  - Needed for tests: injectable command executor and fake response source.

- lib/features/home/ui/smart_coach_screen.dart
  - Blocker: runtime analytics and orchestration dependencies.
  - Needed for tests: isolated content widget and fake coaching view model.
