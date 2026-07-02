#!/bin/bash

echo "🚀 Creating ChronoSpark structure..."

# ---------- APP ----------
mkdir -p lib/app
touch lib/app/app.dart
touch lib/app/app_root.dart
touch lib/app/navigation_shell.dart
touch lib/app/providers.dart

# ---------- CORE ----------
mkdir -p lib/core/theme
mkdir -p lib/core/assets
mkdir -p lib/core/widgets
mkdir -p lib/core/services
mkdir -p lib/core/utils

touch lib/core/theme/app_theme.dart
touch lib/core/assets/app_assets.dart
touch lib/core/widgets/app_background.dart
touch lib/core/widgets/app_tap.dart
touch lib/core/services/audio_service.dart
touch lib/core/services/haptic_service.dart
touch lib/core/services/feedback_service.dart
touch lib/core/utils/format_time.dart

# ---------- DATA ----------
mkdir -p lib/data/models
mkdir -p lib/data/repositories
mkdir -p lib/data/services
mkdir -p lib/data/paywall
mkdir -p lib/data/di

touch lib/data/models/auth_models.dart

touch lib/data/repositories/task_repository.dart
touch lib/data/repositories/log_repository.dart
touch lib/data/repositories/user_repository.dart

touch lib/data/services/auth_service.dart
touch lib/data/services/logs_service.dart
touch lib/data/services/settings_service.dart
touch lib/data/services/workspace_store_service.dart

touch lib/data/paywall/paywall_service.dart
touch lib/data/paywall/entitlement_service.dart
touch lib/data/paywall/receipt_verifier.dart

touch lib/data/di/services_providers.dart
touch lib/data/di/repositories_providers.dart
touch lib/data/di/paywall_providers.dart

# ---------- DOMAIN ----------
mkdir -p lib/domain/models
mkdir -p lib/domain/usecases
mkdir -p lib/domain/logic

touch lib/domain/models/task_model.dart
touch lib/domain/models/focus_session_model.dart
touch lib/domain/models/decision_model.dart

touch lib/domain/usecases/get_best_task.dart
touch lib/domain/usecases/start_focus_session.dart
touch lib/domain/usecases/complete_session.dart

touch lib/domain/logic/scoring_engine.dart
touch lib/domain/logic/fatigue_engine.dart
touch lib/domain/logic/energy_engine.dart
touch lib/domain/logic/planning_engine.dart
touch lib/domain/logic/insight_engine.dart

# ---------- ENGINE ----------
mkdir -p lib/engine
touch lib/engine/si_ai_service.dart

# ---------- FEATURES ----------
mkdir -p lib/features/home
mkdir -p lib/features/plan
mkdir -p lib/features/creator
mkdir -p lib/features/focus
mkdir -p lib/features/logs
mkdir -p lib/features/reflect
mkdir -p lib/features/settings
mkdir -p lib/features/console
mkdir -p lib/features/profile

touch lib/features/home/smart_coach_screen.dart
touch lib/features/plan/chronoflow_screen.dart
touch lib/features/creator/creator_screen.dart
touch lib/features/focus/focus_screen.dart
touch lib/features/logs/logs_screen.dart
touch lib/features/reflect/reflect_screen.dart
touch lib/features/settings/settings_screen.dart
touch lib/features/console/console_screen.dart
touch lib/features/profile/profile_screen.dart

# ---------- MAIN ----------
touch lib/main.dart

echo "✅ ChronoSpark structure created!"