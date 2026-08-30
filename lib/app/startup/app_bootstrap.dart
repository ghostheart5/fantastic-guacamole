import 'dart:async';

import 'package:fantastic_guacamole/app/app_root.dart';
import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/deep_link_service.dart';
import 'package:fantastic_guacamole/config/app_config.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/debug/diagnostics_context_service.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/core/observers/riverpod_observer.dart';
import 'package:fantastic_guacamole/data/services/supabase_client_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/sensitive_prefs_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/data/storage/storage_migration.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart'
    show
        onboardingCompleteProvider,
        onboardingCompleteStorageKey,
        onboardingContentVersionStorageKey,
        onboardingWelcomeCompleteProvider,
        onboardingWelcomeCompleteStorageKey;
import 'package:fantastic_guacamole/state/core/state_bootstrap.dart'
    show stateBootstrapProvider;
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_coordinator_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart'
    show identityServiceProvider;
import 'package:fantastic_guacamole/state/providers/sync_provider.dart'
    show offlineQueueCountProvider;
import 'package:fantastic_guacamole/state/services/intelligence_service.dart';
import 'package:fantastic_guacamole/system/firebase/firebase_bootstrap.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:fantastic_guacamole/system/system_boot.dart';
import 'package:fantastic_guacamole/features/onboarding/domain/onboarding_content_contract.dart';
import 'package:fantastic_guacamole/ui/widgets/error_boundary_widget.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

part 'startup_coordinator.dart';
part 'startup_error_hooks.dart';
part 'startup_models.dart';
part 'startup_preference_migration.dart';
part 'startup_stages.dart';
