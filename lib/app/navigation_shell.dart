import 'dart:async';

import 'package:fantastic_guacamole/app/notification_destination.dart';
import 'package:fantastic_guacamole/app/router/app_route_registry.dart';
import 'package:fantastic_guacamole/app/router/route_guards.dart'
    as route_guards;
import 'package:fantastic_guacamole/state/providers/auth_provider.dart'
    show passwordRecoveryStateProvider;
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';
import 'package:fantastic_guacamole/features/creator/ui/daily_rhythms_screen.dart';
import 'package:fantastic_guacamole/features/creator/ui/record_library_screen.dart';
import 'package:fantastic_guacamole/features/goals/ui/goals_screen.dart';
import 'package:fantastic_guacamole/features/home/ui/smart_planner_screen.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/profile/ui/profile_screen.dart';
import 'package:fantastic_guacamole/features/progression/ui/progression_screen.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/l10n/navigation_copy.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/entitlement_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_scoped_store_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/operating_system_provider.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/app_recovery_provider.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/services/app_recovery_service.dart';
import 'package:fantastic_guacamole/state/services/data_hygiene_scheduler.dart';
import 'package:fantastic_guacamole/state/services/preference_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:fantastic_guacamole/system/voice/audio_interruption_service.dart';
import 'package:fantastic_guacamole/system/system_scheduler.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/ui/navigation/open_schedule.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:fantastic_guacamole/ui/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'navigation_shell_destinations.dart';
part 'navigation_shell_lifecycle.dart';
part 'navigation_shell_notification_routing.dart';
part 'navigation_shell_ui.dart';

@visibleForTesting
const Duration networkReconnectRetryDebounce = Duration(milliseconds: 750);

typedef _ReminderRecoveryOwner = ({String namespace, int generation});

// A shell can mount after Android's initial resumed event, or before account
// storage is ready. Reconcile when that exact account generation becomes usable.
final _reminderRecoveryOwnerProvider = Provider<_ReminderRecoveryOwner?>((ref) {
  final scope = ref.watch(accountStorageScopeProvider);
  final boundary = ref.watch(authSessionBoundaryProvider);
  final namespace = scope.v2Namespace;
  if (!scope.isWritable ||
      namespace == null ||
      boundary.isTransitioning ||
      !boundary.isStorageReady ||
      (boundary.blockingIssue?.trim().isNotEmpty ?? false) ||
      boundary.userId != scope.rawUserId) {
    return null;
  }
  return (namespace: namespace, generation: boundary.generation);
});

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
  ProviderSubscription<AsyncValue<OperatingDecisionReceipt>>?
  _decisionSubscription;
  late final ProviderSubscription<AppView> _viewSubscription;
  late final ProviderSubscription<NetworkInterfaceAvailability>
  _networkAvailabilitySubscription;
  Timer? _entitlementAuthorityRecheckTimer;
  Timer? _networkRetryDebounceTimer;
  final Set<int> _initializedTabIndexes = <int>{};
  bool _savingCurrentState = false;
  // An Activity origin that already existed when this shell mounted belongs to
  // an earlier shell (for example before sign-out) and must not be honoured.
  bool _staleActivityOrigin = false;
  late final ProviderSubscription<_ReminderRecoveryOwner?>
  _reminderRecoverySubscription;
  _ReminderRecoveryOwner? _pendingReminderRecovery;
  bool _reminderRecoveryScheduled = false;
  bool _reminderRecoveryRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(activityOriginProvider) != null) {
      _staleActivityOrigin = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(activityOriginProvider.notifier).set(null);
        _staleActivityOrigin = false;
      });
    }
    _systemScheduler = SystemScheduler()
      ..onSyncOfflineQueue = () {
        if (!mounted || !Env.enableCloudSync) {
          return;
        }
        _triggerCloudSyncReplay();
      };
    if (!_isFlutterTestBinding) {
      _systemScheduler.resume();
    }
    _reminderRecoverySubscription = ref.listenManual(
      _reminderRecoveryOwnerProvider,
      (_, next) {
        _queueReminderRecovery(next);
        // A cold-launch tap waits for this same readiness.
        _routeHeldLaunchPayload();
      },
      fireImmediately: true,
    );
    _viewSubscription = ref.listenManual<AppView>(appFlowProvider, (
      _,
      AppView next,
    ) {
      if (next != AppView.progression) {
        // Activity's origin only applies while Activity is showing.
        ref.read(activityOriginProvider.notifier).set(null);
      }
      if (_isPrimaryView(next)) {
        _initializedTabIndexes.add(_tabIndexForView(next));
        _runBackgroundTask(
          'route recovery save',
          () => ref
              .read(appRecoveryProvider)
              .saveState(lastPrimaryViewName: next.name),
        );
      }
    });
    _networkAvailabilitySubscription = ref
        .listenManual<NetworkInterfaceAvailability>(
          networkInterfaceAvailabilityProvider,
          (
            NetworkInterfaceAvailability? previous,
            NetworkInterfaceAvailability next,
          ) {
            if (next != NetworkInterfaceAvailability.available) {
              _networkRetryDebounceTimer?.cancel();
              _networkRetryDebounceTimer = null;
              return;
            }
            if (previous != NetworkInterfaceAvailability.available) {
              _scheduleNetworkRecoveryRetry();
            }
          },
        );
    _startEntitlementAuthorityRechecks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The shared decision graph serves every shell route. Keep its single
      // subscription live across note overlays and tab TickerMode changes,
      // rather than resuming a dirty async graph during a route build.
      _decisionSubscription = ref.listenManual(
        operatingDecisionReceiptProvider,
        (_, _) {},
      );
      _initializeRuntimeServices();
      if (widget.allowSavedTabRestore) {
        _runBackgroundTask(
          'default launch recovery restore',
          _restoreDefaultLaunchTab,
        );
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
    NotificationScheduler.heldLaunchPayloadListenable.addListener(
      _onHeldLaunchPayload,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationScheduler.tappedPayloadListenable.removeListener(
      _onNotificationTapped,
    );
    NotificationScheduler.heldLaunchPayloadListenable.removeListener(
      _onHeldLaunchPayload,
    );
    _entitlementAuthorityRecheckTimer?.cancel();
    _networkRetryDebounceTimer?.cancel();
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
    _decisionSubscription?.close();
    _viewSubscription.close();
    _networkAvailabilitySubscription.close();
    _reminderRecoverySubscription.close();
    _pendingReminderRecovery = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool oldWasActivityOverlay =
        oldWidget.initialView == AppView.progression &&
        _activityOriginIsPrimary;
    if ((_isPrimaryView(oldWidget.initialView) || oldWasActivityOverlay) &&
        !_isPrimaryView(widget.initialView) &&
        _activityOverlayOrigin == null) {
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
        _runBackgroundTask(
          'default launch recovery restore',
          _restoreDefaultLaunchTab,
        );
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
        _queueReminderRecovery(ref.read(_reminderRecoveryOwnerProvider));
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

  // Class methods (not the extension's), so add and remove get equal tear-offs.
  void _onHeldLaunchPayload() => _routeHeldLaunchPayload();
  void _onNotificationTapped() => _routeTappedNotification();

  @override
  void didChangeLocales(List<Locale>? locales) {
    // Reminder text follows the app language: register it again in the new
    // one (only reminders whose text changed are replaced).
    _queueReminderRecovery(ref.read(_reminderRecoveryOwnerProvider));
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

  /// The primary view whose tab bar stays visible under Activity, or null when
  /// Activity was opened any other way (or another view is showing).
  AppView? get _activityOverlayOrigin {
    if (widget.initialView != AppView.progression) return null;
    return _activityOriginIsPrimary ? ref.read(activityOriginProvider) : null;
  }

  bool get _activityOriginIsPrimary {
    final AppView? origin = ref.read(activityOriginProvider);
    return !_staleActivityOrigin && origin != null && _isPrimaryView(origin);
  }

  void _goToView(AppView view) {
    final String routePath = routePathForAppView(view);
    try {
      // Explicit Back/navigation and notification taps must replace any
      // callback or redirect stack and close screens pushed above the shell.
      if (goToAppRoutePath(context, routePath)) return;
    } on Object {
      // Widget tests and standalone shell previews may mount the shell without
      // a GoRouter. Only those previews use the compatibility provider.
    }
    _syncAppFlowToRouteView(view);
  }

  @override
  Widget build(BuildContext context) {
    final AppView view = widget.initialView;
    ref.watch(activityOriginProvider);
    final AppView? activityOrigin = _activityOverlayOrigin;
    final int tabIndex = _tabIndexForView(activityOrigin ?? view);
    if (_isPrimaryView(view) || activityOrigin != null) {
      _initializedTabIndexes.add(tabIndex);
    }

    final Widget body = switch (view) {
      AppView.nexus ||
      AppView.console ||
      AppView.trajectoryEngine ||
      AppView.timeline => _buildPrimaryShell(tabIndex),
      AppView.smartPlanner => const SmartPlannerScreen(),
      AppView.profile => const ProfileScreen(),
      AppView.settings => const SettingsScreen(),
      AppView.progression =>
        activityOrigin == null
            ? const ProgressionScreen()
            : _buildPrimaryShell(tabIndex, overlay: const ProgressionScreen()),
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
          _goToView(activityOrigin ?? AppView.nexus);
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
