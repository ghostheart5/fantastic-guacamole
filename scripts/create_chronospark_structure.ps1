$ErrorActionPreference = 'Stop'

Write-Host 'Creating ChronoSpark structure...'

$paths = @(
  'lib/app',
  'lib/core/theme',
  'lib/core/assets',
  'lib/core/widgets',
  'lib/core/services',
  'lib/core/utils',
  'lib/data/models',
  'lib/data/repositories',
  'lib/data/services',
  'lib/data/paywall',
  'lib/data/di',
  'lib/domain/models',
  'lib/domain/usecases',
  'lib/domain/logic',
  'lib/engine',
  'lib/features/home',
  'lib/features/plan',
  'lib/features/creator',
  'lib/features/focus',
  'lib/features/logs',
  'lib/features/reflect',
  'lib/features/settings',
  'lib/features/console',
  'lib/features/profile'
)

foreach ($dir in $paths) {
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$files = @(
  'lib/app/app.dart',
  'lib/app/app_root.dart',
  'lib/app/navigation_shell.dart',
  'lib/app/providers.dart',
  'lib/core/theme/app_theme.dart',
  'lib/core/assets/app_assets.dart',
  'lib/core/widgets/app_background.dart',
  'lib/core/widgets/app_tap.dart',
  'lib/core/services/audio_service.dart',
  'lib/core/services/haptic_service.dart',
  'lib/core/services/feedback_service.dart',
  'lib/core/utils/format_time.dart',
  'lib/data/models/auth_models.dart',
  'lib/data/repositories/task_repository.dart',
  'lib/data/repositories/log_repository.dart',
  'lib/data/repositories/user_repository.dart',
  'lib/data/services/auth_service.dart',
  'lib/data/services/logs_service.dart',
  'lib/data/services/settings_service.dart',
  'lib/data/services/workspace_store_service.dart',
  'lib/data/paywall/paywall_service.dart',
  'lib/data/paywall/entitlement_service.dart',
  'lib/data/paywall/receipt_verifier.dart',
  'lib/data/di/services_providers.dart',
  'lib/data/di/repositories_providers.dart',
  'lib/data/di/paywall_providers.dart',
  'lib/domain/models/task_model.dart',
  'lib/domain/models/focus_session_model.dart',
  'lib/domain/models/decision_model.dart',
  'lib/domain/usecases/get_best_task.dart',
  'lib/domain/usecases/start_focus_session.dart',
  'lib/domain/usecases/complete_session.dart',
  'lib/domain/logic/scoring_engine.dart',
  'lib/domain/logic/fatigue_engine.dart',
  'lib/domain/logic/energy_engine.dart',
  'lib/domain/logic/planning_engine.dart',
  'lib/domain/logic/insight_engine.dart',
  'lib/engine/si_ai_service.dart',
  'lib/features/home/smart_coach_screen.dart',
  'lib/features/plan/chronoflow_screen.dart',
  'lib/features/creator/creator_screen.dart',
  'lib/features/focus/focus_screen.dart',
  'lib/features/logs/logs_screen.dart',
  'lib/features/reflect/reflect_screen.dart',
  'lib/features/settings/settings_screen.dart',
  'lib/features/console/console_screen.dart',
  'lib/features/profile/profile_screen.dart',
  'lib/main.dart'
)

foreach ($file in $files) {
  if (-not (Test-Path $file)) {
    New-Item -ItemType File -Path $file | Out-Null
  }
}

Write-Host 'ChronoSpark structure created.'