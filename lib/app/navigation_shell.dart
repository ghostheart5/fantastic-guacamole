import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';

import 'package:fantastic_guacamole/features/home/ui/smart_coach_screen.dart';

import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/profile/ui/profile_screen.dart';
import 'package:fantastic_guacamole/features/progression/ui/progression_screen.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/providers/supabase_sync_queue_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/session_recovery_provider.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/services/data_hygiene_scheduler.dart';
import 'package:fantastic_guacamole/system/system_scheduler.dart';
import 'package:fantastic_guacamole/ui/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavigationShell extends ConsumerStatefulWidget {
  const NavigationShell({super.key, this.initialView = AppView.nexus});

  final AppView initialView;

  @override
  ConsumerState<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends ConsumerState<NavigationShell>
    with WidgetsBindingObserver {
  late final SystemScheduler _systemScheduler;
  late final DataHygieneScheduler _dataHygieneScheduler;
  late final ProviderSubscription<double> _energySubscription;
  late final ProviderSubscription<LearningState> _learningSubscription;
  late final ProviderSubscription<AppView> _viewSubscription;
  late final ProviderSubscription<bool> _networkOnlineSubscription;

  final Set<int> _initializedTabIndexes = <int>{0};

  bool _disposed = false;
  DateTime? _lastActivationLockNoticeAt;

  bool get _isFlutterTestBinding {
    final String bindingType = WidgetsBinding.instance.runtimeType.toString();
    return bindingType.contains('TestWidgetsFlutterBinding');
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _systemScheduler = SystemScheduler()
      ..onSyncOfflineQueue = () {
        if (!mounted || _disposed || !Env.enableCloudSync) {
          return;
        }

        ref.invalidate(replayOfflineQueueProvider);
        ref.invalidate(syncToCloudProvider);
      }
      ..onPrecomputeAI = () {
        if (!mounted || _disposed) {
          return;
        }

        ref.invalidate(aiDecisionProvider);
      };

    if (!_isFlutterTestBinding) {
      _systemScheduler.resume();
    }

    _dataHygieneScheduler = ref.read(dataHygieneSchedulerProvider);

    if (!_isFlutterTestBinding) {
      _dataHygieneScheduler.start();
    }

    _energySubscription = ref.listenManual<double>(energyProvider, (_, _) {
      if (!mounted || _disposed) {
        return;
      }

      ref.invalidate(aiDecisionProvider);
      ref.invalidate(aiResponseProvider);
    });

    _learningSubscription = ref.listenManual<LearningState>(learningProvider, (
      _,
      _,
    ) {
      if (!mounted || _disposed) {
        return;
      }

      ref.invalidate(aiDecisionProvider);
      ref.invalidate(aiResponseProvider);
    });

    _viewSubscription = ref.listenManual<AppView>(appFlowProvider, (
      _,
      AppView next,
    ) {
      if (!mounted || _disposed) {
        return;
      }

      final AppView effectiveView = _enforceActivationView(
        next,
        announceIfLocked: false,
      );

      _initializedTabIndexes.add(_tabIndexForView(effectiveView));

      final sessionRecovery = ref.read(sessionRecoveryProvider);
      final AppView recoverableView = _recoverableSessionView(effectiveView);

      unawaited(sessionRecovery.saveState(lastRoute: recoverableView.name));
    });

    _networkOnlineSubscription = ref.listenManual<bool>(isOnlineProvider, (
      bool? previous,
      bool next,
    ) {
      if (!mounted || _disposed) {
        return;
      }

      final bool cameBackOnline =
          next && (previous == null || previous == false);

      if (!cameBackOnline) {
        return;
      }

      _triggerCloudSyncReplay();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed) {
        return;
      }

      ref
          .read(appFlowProvider.notifier)
          .show(_enforceActivationView(AppView.nexus, announceIfLocked: false));
      unawaited(_checkRecovery());
    });
  }

  @override
  void dispose() {
    _disposed = true;

    WidgetsBinding.instance.removeObserver(this);

    _systemScheduler.shutdown();
    _dataHygieneScheduler.shutdown();

    _energySubscription.close();
    _learningSubscription.close();
    _viewSubscription.close();
    _networkOnlineSubscription.close();

    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialView != widget.initialView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _disposed) {
          return;
        }

        final AppView next = _enforceActivationView(
          widget.initialView,
          announceIfLocked: false,
        );
        ref.read(appFlowProvider.notifier).show(next);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) {
      return;
    }

    switch (state) {
      case AppLifecycleState.detached:
        _systemScheduler.shutdown();
        _dataHygieneScheduler.shutdown();

        if (mounted && !_disposed) {
          unawaited(_saveCurrentState());
        }
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (!_isFlutterTestBinding) {
          _systemScheduler.pause();
          _dataHygieneScheduler.pause();
        }

        if (mounted && !_disposed) {
          unawaited(_saveCurrentState());
        }
        break;

      case AppLifecycleState.resumed:
        if (!_isFlutterTestBinding) {
          _systemScheduler.resume();
          _dataHygieneScheduler.start();
        }

        if (mounted && !_disposed) {
          _maybeAutoFlushSupabaseQueueOnResume();
          unawaited(_checkRecovery());
        }
        break;
    }
  }

  void _maybeAutoFlushSupabaseQueueOnResume() {
    if (!Env.enableCloudSync || !Env.enableSupabaseAutoQueueFlush) {
      return;
    }

    final supabaseClient = ref.read(supabaseClientProvider);
    if (supabaseClient?.auth.currentUser == null) {
      return;
    }

    ref.invalidate(flushSupabaseSyncQueueProvider);
  }

  Future<void> _saveCurrentState() async {
    if (!mounted || _disposed) {
      return;
    }

    final AppView view = ref.read(appFlowProvider);
    final sessionRecovery = ref.read(sessionRecoveryProvider);

    await sessionRecovery.saveState(lastRoute: view.name);

    if (!mounted || _disposed) {
      return;
    }

    unawaited(_pushDailyMetrics());
  }

  Future<void> _pushDailyMetrics() async {
    if (!mounted || _disposed) {
      return;
    }

    final accumulator = ref.read(localMetricsAccumulatorProvider);
    final aggregationService = ref.read(globalAggregationServiceProvider);

    final Map<String, dynamic> snapshot = await accumulator.snapshot();

    if (!mounted || _disposed) {
      return;
    }

    await aggregationService.push(snapshot);
  }

  Future<void> _checkRecovery() async {
    if (!mounted || _disposed) {
      return;
    }

    final sessionRecovery = ref.read(sessionRecoveryProvider);
    final recovery = await sessionRecovery.loadState();

    if (!mounted || _disposed || recovery == null) {
      return;
    }

    final AppView? recoveredView = appViewFromName(recovery.lastRoute);

    if (recoveredView != null) {
      final AppView target = _enforceActivationView(
        _recoverableSessionView(recoveredView),
        announceIfLocked: false,
      );
      ref.read(appFlowProvider.notifier).show(target);
      return;
    }

    final AppView? requiredActivationView = _requiredActivationView();
    if (requiredActivationView != null) {
      ref.read(appFlowProvider.notifier).show(requiredActivationView);
    }
  }

  AppView? _requiredActivationView() {
    final OnboardingStatus onboardingStatus = ref.read(onboardingStatusProvider);
    if (onboardingStatus == OnboardingStatus.unknown) {
      return AppView.nexus;
    }

    if (onboardingStatus == OnboardingStatus.incomplete) {
      return AppView.creator;
    }

    final bool hasCreatedFirstItem = ref.read(creatorFirstItemCreatedProvider);
    if (!hasCreatedFirstItem) {
      return AppView.creator;
    }

    final bool hasCompletedTimelineFirstAction = ref.read(
      timelineFirstActionCompletedProvider,
    );
    if (!hasCompletedTimelineFirstAction) {
      return AppView.timeline;
    }

    return null;
  }

  AppView _enforceActivationView(
    AppView requested, {
    required bool announceIfLocked,
  }) {
    final AppView? required = _requiredActivationView();
    if (required == null || requested == required) {
      return requested;
    }
    if (announceIfLocked) {
      _showActivationLockNotice(required);
    }
    return required;
  }

  void _showActivationLockNotice(AppView requiredView) {
    final DateTime now = DateTime.now();
    final DateTime? previous = _lastActivationLockNoticeAt;
    if (previous != null && now.difference(previous).inMilliseconds < 900) {
      return;
    }
    _lastActivationLockNoticeAt = now;

    if (!mounted || _disposed) {
      return;
    }

    final String directive = switch (requiredView) {
      AppView.creator => 'create your first item',
      AppView.smartCoach => 'review Smart Planner',
      AppView.timeline => 'review your timeline',
      AppView.nexus => 'continue setup',
      _ => 'continue setup',
    };

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Finish your first setup to continue. Next: $directive.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _triggerCloudSyncReplay() {
    if (!mounted || _disposed || !Env.enableCloudSync) {
      return;
    }

    ref.invalidate(replayOfflineQueueProvider);
    ref.invalidate(syncToCloudProvider);
    ref.invalidate(offlineQueueCountProvider);
  }

  AppView _recoverableSessionView(AppView view) {
    return switch (view) {
      AppView.creator => AppView.creator,
      AppView.timeline => AppView.timeline,
      AppView.profile => AppView.profile,
      AppView.nexus || AppView.coach => AppView.coach,
      _ => AppView.coach,
    };
  }

  int _tabIndexForView(AppView view) {
    return switch (view) {
      AppView.coach || AppView.nexus => 0,
      AppView.creator => 1,
      AppView.timeline => 2,
      AppView.profile => 3,
      _ => 0,
    };
  }

  Widget _buildTabbedBody(int tabIndex) {
    Widget tabAt(int index) {
      if (!_initializedTabIndexes.contains(index)) {
        return const SizedBox.shrink();
      }

      return switch (index) {
        1 => const CreatorScreen(),
        2 => const TimelineScreen(),
        3 => const ProfileScreen(),
        _ => const NexusScreen(),
      };
    }

    return IndexedStack(
      index: tabIndex,
      children: <Widget>[tabAt(0), tabAt(1), tabAt(2), tabAt(3)],
    );
  }

  void _showNavigationMap() {
    if (!mounted || _disposed) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        Widget navItem(String title, String subtitle, AppView target) {
          final AppView resolvedTarget = _enforceActivationView(
            target,
            announceIfLocked: false,
          );
          final bool locked = resolvedTarget != target;
          return ListTile(
            dense: true,
            title: Text(title),
            subtitle: Text(
              locked ? 'Finish your first setup to continue.' : subtitle,
            ),
            trailing: Icon(locked ? Icons.lock_outline : Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pop();

              if (!mounted || _disposed) {
                return;
              }

              final AppView next = _enforceActivationView(
                target,
                announceIfLocked: true,
              );
              ref.read(appFlowProvider.notifier).show(next);
            },
          );
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
            children: <Widget>[
              const ListTile(
                title: Text('Navigation Map'),
                subtitle: Text('Core first, advanced when needed.'),
              ),
              const Divider(),
              navItem('Nexus', 'Main home view', AppView.nexus),
              navItem('Creator', 'Planning, tasks, and goals', AppView.creator),
              navItem('Timeline', 'Activity and events', AppView.timeline),
              navItem('Profile', 'Identity and progression', AppView.profile),
              const Divider(),
              navItem(
                'Progression',
                'Levels, streaks, and progression',
                AppView.progression,
              ),
              navItem('Settings', 'Preferences and controls', AppView.settings),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppView view = ref.watch(appFlowProvider);
    final AppView enforcedView = _enforceActivationView(
      view,
      announceIfLocked: false,
    );
    if (enforcedView != view) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _disposed) {
          return;
        }
        ref.read(appFlowProvider.notifier).show(enforcedView);
      });
    }

    final int tabIndex = _tabIndexForView(enforcedView);

    _initializedTabIndexes.add(tabIndex);

    final Widget body = switch (enforcedView) {
      AppView.coach ||
      AppView.nexus ||
      AppView.creator ||
      AppView.timeline ||
      AppView.profile => Scaffold(
        floatingActionButton: FloatingActionButton.small(
          onPressed: _showNavigationMap,
          child: const Icon(Icons.map_outlined),
        ),
        body: _buildTabbedBody(tabIndex),
      ),

      AppView.smartCoach => const SmartCoachScreen(),
      AppView.console => const SIConsoleScreen(),
      AppView.settings => const SettingsScreen(),
      AppView.trajectoryEngine => const TrajectoryEngineScreen(),
      AppView.progression => const ProgressionScreen(),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic _) {
        if (didPop || !mounted || _disposed) {
          return;
        }

        final AppFlowController controller = ref.read(appFlowProvider.notifier);
        final AppView current = _enforceActivationView(
          ref.read(appFlowProvider),
          announceIfLocked: false,
        );

        final AppView? requiredActivationView = _requiredActivationView();
        if (requiredActivationView != null &&
            current != requiredActivationView) {
          controller.show(requiredActivationView);
          return;
        }

        if (current != AppView.nexus &&
            current != AppView.creator &&
            current != AppView.timeline &&
            current != AppView.profile) {
          controller.toNexus();
          return;
        }

        if (current == AppView.creator ||
            current == AppView.timeline ||
            current == AppView.profile) {
          controller.toNexus();
          return;
        }

        controller.toNexus();
      },
      child: OfflineBanner(child: body),
    );
  }
}
