import '../../data/repositories/chronologs_repository.dart';
import '../../data/repositories/chronologs_repository_impl.dart';
import '../../data/repositories/mission_repository.dart';
import '../../data/repositories/mission_repository_impl.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/repositories/temporal_repository.dart';
import '../../data/repositories/temporal_repository_impl.dart';
import '../../features/chronocreator/controllers/creator_controller.dart';
import '../../features/chronologs/controllers/chronologs_controller.dart';
import '../../features/settings/controllers/settings_controller.dart';
import '../../features/si_console/controllers/si_console_controller.dart';
import '../../features/temporal_ops/controllers/temporal_ops_controller.dart';

/// Single composition root.
/// Holds one repository instance per module and vends pre-wired controllers.
class AppLocator {
  AppLocator._();

  static final AppLocator instance = AppLocator._();

  // ── Repositories (singletons) ──────────────────────────────────────────────
  late final MissionRepository missionRepository = MissionRepositoryImpl();
  late final ChronologsRepository chronologsRepository = ChronologsRepositoryImpl();
  late final TemporalRepository temporalRepository = TemporalRepositoryImpl();
  late final SettingsRepository settingsRepository = SettingsRepositoryImpl();

  // ── Controller factories ───────────────────────────────────────────────────
  /// Returns a fresh [CreatorController] injected with the mission repository.
  CreatorController creatorController() => CreatorController(repository: missionRepository);

  /// Returns a fresh [ChronoLogsController] injected with the logs repository.
  ChronoLogsController chronoLogsController() =>
      ChronoLogsController(repository: chronologsRepository);

  /// Returns a fresh [TemporalOpsController] injected with the temporal repository.
  TemporalOpsController temporalOpsController() =>
      TemporalOpsController(repository: temporalRepository);

  /// Returns a fresh [SettingsController] injected with the settings repository.
  SettingsController settingsController() => SettingsController(repository: settingsRepository);

  /// Returns a fresh [SIConsoleController] (no external data dependency).
  SIConsoleController siConsoleController() => SIConsoleController();
}
