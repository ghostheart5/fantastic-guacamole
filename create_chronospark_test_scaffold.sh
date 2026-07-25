#!/usr/bin/env bash

set -e

ROOT="test"

create_dir() {
    mkdir -p "$1"
    echo "[DIR ] $1"
}

create_file() {
    mkdir -p "$(dirname "$1")"
    touch "$1"
    echo "[FILE] $1"
}

echo "======================================="
echo " Building ChronoSpark Test Structure"
echo "======================================="

# Root Categories
create_dir "$ROOT/smoke"
create_dir "$ROOT/unit/models"
create_dir "$ROOT/unit/repositories"
create_dir "$ROOT/unit/services"
create_dir "$ROOT/unit/providers"
create_dir "$ROOT/unit/usecases"
create_dir "$ROOT/unit/utilities"

create_dir "$ROOT/widget/auth"
create_dir "$ROOT/widget/home"
create_dir "$ROOT/widget/goals"
create_dir "$ROOT/widget/tasks"
create_dir "$ROOT/widget/timeline"
create_dir "$ROOT/widget/nexus"
create_dir "$ROOT/widget/smart_coach"
create_dir "$ROOT/widget/flowmap"
create_dir "$ROOT/widget/soul_map"
create_dir "$ROOT/widget/analytics"
create_dir "$ROOT/widget/settings"

create_dir "$ROOT/integration/auth"
create_dir "$ROOT/integration/onboarding"
create_dir "$ROOT/integration/goals"
create_dir "$ROOT/integration/tasks"
create_dir "$ROOT/integration/timeline"
create_dir "$ROOT/integration/smart_coach"
create_dir "$ROOT/integration/nexus"
create_dir "$ROOT/integration/subscriptions"

create_dir "$ROOT/regression"
create_dir "$ROOT/performance"
create_dir "$ROOT/security"
create_dir "$ROOT/accessibility"
create_dir "$ROOT/golden"
create_dir "$ROOT/fixtures"
create_dir "$ROOT/mocks"
create_dir "$ROOT/helpers"
create_dir "$ROOT/audit"

# Smoke
create_file "$ROOT/smoke/app_startup_test.dart"
create_file "$ROOT/smoke/navigation_smoke_test.dart"

# Models
create_file "$ROOT/unit/models/user_model_test.dart"
create_file "$ROOT/unit/models/task_model_test.dart"
create_file "$ROOT/unit/models/goal_model_test.dart"
create_file "$ROOT/unit/models/timeline_event_model_test.dart"
create_file "$ROOT/unit/models/memory_model_test.dart"

# Repositories
create_file "$ROOT/unit/repositories/auth_repository_test.dart"
create_file "$ROOT/unit/repositories/goals_repository_test.dart"
create_file "$ROOT/unit/repositories/tasks_repository_test.dart"
create_file "$ROOT/unit/repositories/timeline_repository_test.dart"
create_file "$ROOT/unit/repositories/memory_repository_test.dart"

# Services
create_file "$ROOT/unit/services/si_engine_test.dart"
create_file "$ROOT/unit/services/smart_coach_service_test.dart"
create_file "$ROOT/unit/services/analytics_service_test.dart"
create_file "$ROOT/unit/services/progression_service_test.dart"

# Providers
create_file "$ROOT/unit/providers/auth_provider_test.dart"
create_file "$ROOT/unit/providers/goals_provider_test.dart"
create_file "$ROOT/unit/providers/tasks_provider_test.dart"
create_file "$ROOT/unit/providers/timeline_provider_test.dart"
create_file "$ROOT/unit/providers/progression_provider_test.dart"

# Usecases
create_file "$ROOT/unit/usecases/create_goal_usecase_test.dart"
create_file "$ROOT/unit/usecases/complete_goal_usecase_test.dart"
create_file "$ROOT/unit/usecases/create_task_usecase_test.dart"
create_file "$ROOT/unit/usecases/generate_memory_insights_usecase_test.dart"
create_file "$ROOT/unit/usecases/view_goal_streaks_usecase_test.dart"

# Widget Tests
create_file "$ROOT/widget/auth/login_screen_test.dart"
create_file "$ROOT/widget/auth/register_screen_test.dart"
create_file "$ROOT/widget/auth/email_verification_test.dart"

create_file "$ROOT/widget/home/home_screen_test.dart"

create_file "$ROOT/widget/goals/goals_screen_test.dart"
create_file "$ROOT/widget/tasks/tasks_screen_test.dart"
create_file "$ROOT/widget/timeline/timeline_screen_test.dart"
create_file "$ROOT/widget/nexus/nexus_screen_test.dart"
create_file "$ROOT/widget/smart_coach/smart_coach_screen_test.dart"
create_file "$ROOT/widget/flowmap/flowmap_screen_test.dart"
create_file "$ROOT/widget/soul_map/soul_map_screen_test.dart"
create_file "$ROOT/widget/analytics/analytics_screen_test.dart"
create_file "$ROOT/widget/settings/settings_screen_test.dart"

# Integration
create_file "$ROOT/integration/auth/google_signin_flow_test.dart"
create_file "$ROOT/integration/auth/email_signin_flow_test.dart"
create_file "$ROOT/integration/auth/persistent_session_test.dart"

create_file "$ROOT/integration/onboarding/tutorial_flow_test.dart"

create_file "$ROOT/integration/goals/goal_lifecycle_test.dart"
create_file "$ROOT/integration/tasks/task_lifecycle_test.dart"
create_file "$ROOT/integration/timeline/timeline_generation_test.dart"

create_file "$ROOT/integration/smart_coach/coach_generation_test.dart"
create_file "$ROOT/integration/nexus/nexus_sync_test.dart"

create_file "$ROOT/integration/subscriptions/premium_upgrade_test.dart"

# Release Readiness
create_file "$ROOT/regression/release_blockers_test.dart"

create_file "$ROOT/performance/home_load_test.dart"
create_file "$ROOT/performance/timeline_render_test.dart"

create_file "$ROOT/security/auth_security_test.dart"
create_file "$ROOT/security/session_security_test.dart"

create_file "$ROOT/accessibility/accessibility_audit_test.dart"

create_file "$ROOT/golden/home_screen_golden_test.dart"

# Helpers / Mocks
create_file "$ROOT/helpers/test_helpers.dart"
create_file "$ROOT/helpers/test_fixtures.dart"

create_file "$ROOT/mocks/mock_auth_repository.dart"
create_file "$ROOT/mocks/mock_goals_repository.dart"

echo ""
echo "======================================="
echo " ChronoSpark Test Scaffold Complete"
echo "======================================="
echo ""
echo "Folder Count:"
find "$ROOT" -type d | wc -l
echo ""
echo "File Count:"
find "$ROOT" -type f | wc -l