import 'dart:async';

import 'package:fantastic_guacamole/app/router/app_route_registry.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';
import 'package:fantastic_guacamole/features/goals/ui/goals_screen.dart';
import 'package:fantastic_guacamole/features/home/ui/smart_planner_screen.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/profile/ui/profile_screen.dart';
import 'package:fantastic_guacamole/features/progression/ui/progression_screen.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/energy_provider.dart';
import 'package:fantastic_guacamole/state/providers/entitlement_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_scoped_store_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/app_recovery_provider.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:fantastic_guacamole/state/services/data_hygiene_scheduler.dart';
import 'package:fantastic_guacamole/state/services/preference_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:fantastic_guacamole/system/voice/audio_interruption_service.dart';
import 'package:fantastic_guacamole/system/system_scheduler.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:fantastic_guacamole/ui/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

part 'navigation_shell_destinations.dart';
part 'navigation_shell_lifecycle.dart';
part 'navigation_shell_notification_routing.dart';
part 'navigation_shell_ui.dart';

class NavigationShell extends ConsumerStatefulWidget {
  const NavigationShell({
    super.key,
    this.initialView = AppView.nexus,
    this.allowSavedTabRestore = false,
  });

  final AppView initialView;
  final bool allowSavedTabRestore;

  @override
  ConsumerState<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends ConsumerState<NavigationShell>
    with WidgetsBindingObserver {
  PreferenceService get _preferenceService =>
      ref.read(preferenceServiceProvider);
  late final SystemScheduler _systemScheduler;
  DataHygieneScheduler? _dataHygieneScheduler;
  AudioInterruptionService? _audioInterruptionService;
  bool _audioInterruptionStarted = false;
  late final ProviderSubscription<double> _energySubscription;
  late final ProviderSubscription<LearningState> _learningSubscription;
  late final ProviderSubscription<AppView> _viewSubscription;
  late final ProviderSubscription<bool> _networkOnlineSubscription;
  Timer? _entitlementAuthorityRecheckTimer;
  final Set<int> _initializedTabIndexes = <int>{};
  bool _savingCurrentState = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _systemScheduler = SystemScheduler()
      ..onSyncOfflineQueue = () {
        if (!mounted || !Env.enableCloudSync) {
          return;
        }
        ref.invalidate(replayOfflineQueueProvider);
        ref.invalidate(syncToCloudProvider);
      };
    if (!_isFlutterTestBinding) {
      _systemScheduler.resume();
    }
    _energySubscription = ref.listenManual<double>(energyProvider, (_, _) {
      ref.invalidate(aiDecisionProvider);
      ref.invalidate(aiResponseProvider);
      ref.invalidate(smartPlannerAiResponseProvider);
    });
    _learningSubscription = ref.listenManual<LearningState>(learningProvider, (
      _,
      _,
    ) {
      ref.invalidate(aiDecisionProvider);
      ref.invalidate(aiResponseProvider);
      ref.invalidate(smartPlannerAiResponseProvider);
    });
    _viewSubscription = ref.listenManual<AppView>(appFlowProvider, (
      _,
      AppView next,
    ) {
      if (_isPrimaryView(next)) {
        _initializedTabIndexes.add(_tabIndexForView(next));
      }
      _runBackgroundTask(
        'route recovery save',
        () => ref.read(appRecoveryProvider).saveState(lastRoute: next.name),
      );
    });
    _networkOnlineSubscription = ref.listenManual<bool>(isOnlineProvider, (
      bool? previous,
      bool next,
    ) {
      final bool cameBackOnline =
          next && (previous == null || previous == false);
      if (!cameBackOnline) {
        return;
      }
      _triggerCloudSyncReplay();
      _runBackgroundTask(
        'subscription authority refresh',
        () => ref.read(entitlementAuthorityRefreshProvider)(force: true),
      );
    });
    _startEntitlementAuthorityRechecks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeRuntimeServices();
      if (widget.allowSavedTabRestore) {
        _restoreDefaultLaunchTab();
      } else {
        _syncAppFlowToRouteView(widget.initialView);
      }
      _runBackgroundTask(
        'notification launch handling',
        _handleNotificationLaunch,
      );
    });
    NotificationScheduler.tappedPayloadListenable.addListener(
      _onNotificationTapped,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationScheduler.tappedPayloadListenable.removeListener(
      _onNotificationTapped,
    );
    _entitlementAuthorityRecheckTimer?.cancel();
    _systemScheduler.shutdown();
    _dataHygieneScheduler?.shutdown();
    final AudioInterruptionService? audioInterruptionService =
        _audioInterruptionService;
    if (audioInterruptionService != null) {
      _runBackgroundTask(
        'audio interruption shutdown',
        audioInterruptionService.stop,
      );
    }
    _energySubscription.close();
    _learningSubscription.close();
    _viewSubscription.close();
    _networkOnlineSubscription.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_isPrimaryView(oldWidget.initialView) &&
        !_isPrimaryView(widget.initialView)) {
      // The primary IndexedStack is removed while a secondary screen is open.
      // Its elements are no longer retained, so its initialization cache must
      // not cause stale inactive tabs to be remounted on the return build.
      _initializedTabIndexes.clear();
    }

    final bool receivedSavedTabRestore =
        widget.allowSavedTabRestore && !oldWidget.allowSavedTabRestore;
    if (receivedSavedTabRestore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncAppFlowToRouteView(widget.initialView);
        _restoreDefaultLaunchTab();
      });
      return;
    }

    if (oldWidget.initialView != widget.initialView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncAppFlowToRouteView(widget.initialView);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        _entitlementAuthorityRecheckTimer?.cancel();
        _systemScheduler.shutdown();
        _dataHygieneScheduler?.shutdown();
        _runBackgroundTask('voice playback shutdown', _stopVoicePlayback);
        _runBackgroundTask('lifecycle recovery save', _saveCurrentState);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _entitlementAuthorityRecheckTimer?.cancel();
        if (!_isFlutterTestBinding) {
          _systemScheduler.pause();
          _dataHygieneScheduler?.pause();
        }
        // Otherwise a long SI response or planner summary keeps speaking over
        // whatever the user does next after backgrounding the app.
        _runBackgroundTask('voice playback shutdown', _stopVoicePlayback);
        _runBackgroundTask('lifecycle recovery save', _saveCurrentState);
        break;
      case AppLifecycleState.resumed:
        _startEntitlementAuthorityRechecks();
        if (!_isFlutterTestBinding) {
          _initializeRuntimeServices();
          _systemScheduler.resume();
        }
        _runBackgroundTask(
          'subscription authority refresh',
          () => ref.read(entitlementAuthorityRefreshProvider)(force: true),
        );
        _syncAppFlowToRouteView(widget.initialView);
        break;
    }
  }

  void _startEntitlementAuthorityRechecks() {
    _entitlementAuthorityRecheckTimer?.cancel();
    final Duration interval = ref.read(
      entitlementAuthorityRecheckIntervalProvider,
    );
    if (interval <= Duration.zero) {
      return;
    }
    _entitlementAuthorityRecheckTimer = Timer.periodic(interval, (_) {
      if (!mounted || !ref.read(runtimePremiumAccessProvider)) {
        return;
      }
      _runBackgroundTask(
        'foreground subscription authority refresh',
        () => ref.read(entitlementAuthorityRefreshProvider)(force: true),
      );
    });
  }

  void _syncAppFlowToRouteView(AppView view) {
    if (_isPrimaryView(view)) {
      _initializedTabIndexes.add(_tabIndexForView(view));
    }
    if (ref.read(appFlowProvider) != view) {
      ref.read(appFlowProvider.notifier).show(view);
    }
  }

  void _goToView(AppView view) {
    final String routePath = routePathForAppView(view);
    try {
      final GoRouter router = GoRouter.of(context);
      final Uri currentUri = router.routeInformationProvider.value.uri;
      if (currentUri.path != routePath || currentUri.hasQuery) {
        router.go(routePath);
      }
      return;
    } on Object {
      // Widget tests and standalone shell previews may mount the shell without
      // a GoRouter. Only those previews use the compatibility provider.
    }
    _syncAppFlowToRouteView(view);
  }

  @override
  Widget build(BuildContext context) {
    final AppView view = widget.initialView;
    final int tabIndex = _tabIndexForView(view);
    if (_isPrimaryView(view)) {
      _initializedTabIndexes.add(tabIndex);
    }

    final Widget body = switch (view) {
      AppView.nexus ||
      AppView.profile ||
      AppView.trajectoryEngine ||
      AppView.timeline => _buildPrimaryShell(tabIndex),
      AppView.smartPlanner => const SmartPlannerScreen(),
      AppView.console => const SIConsoleScreen(),
      AppView.settings => const SettingsScreen(),
      AppView.progression => const ProgressionScreen(),
      AppView.creator => const CreatorScreen(),
      AppView.goals => const GoalsScreen(),
    };

    return PopScope(
      canPop: view == AppView.nexus,
      onPopInvokedWithResult: (bool didPop, dynamic _) {
        if (didPop) {
          return;
        }
        final AppView current = widget.initialView;

        if (current != AppView.nexus) {
          _goToView(AppView.nexus);
          return;
        }

        unawaited(
          runGuardedBackgroundTask(
            label: 'application exit',
            task: () => SystemNavigator.pop(),
          ),
        );
      },
      child: OfflineBanner(child: body),
    );
  }
}
