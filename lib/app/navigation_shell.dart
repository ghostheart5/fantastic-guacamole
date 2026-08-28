import 'dart:async';

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
import 'package:fantastic_guacamole/state/providers/energy_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/app_recovery_provider.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:fantastic_guacamole/state/services/data_hygiene_scheduler.dart';
import 'package:fantastic_guacamole/state/services/preference_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:fantastic_guacamole/system/voice/audio_interruption_service.dart';
import 'package:fantastic_guacamole/system/system_scheduler.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:fantastic_guacamole/ui/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

@visibleForTesting
Future<void> runGuardedBackgroundTask({
  required String label,
  required Future<void> Function() task,
}) async {
  try {
    await task();
  } on Object catch (error) {
    Logger.warn('Background task "$label" failed (${error.runtimeType}).');
  }
}

class _PrimaryDestination {
  const _PrimaryDestination({required this.label, required this.assetPath});

  final String label;
  final String assetPath;
}

const List<_PrimaryDestination> _primaryDestinations = <_PrimaryDestination>[
  _PrimaryDestination(label: 'Nexus', assetPath: AppAssets.iconNexus),
  _PrimaryDestination(label: 'Trajectory', assetPath: AppAssets.iconTasks),
  _PrimaryDestination(label: 'Timeline', assetPath: AppAssets.iconLogs),
  _PrimaryDestination(label: 'Profile', assetPath: AppAssets.iconProfile),
];

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
  final PreferenceService _preferenceService = PreferenceService();
  late final SystemScheduler _systemScheduler;
  DataHygieneScheduler? _dataHygieneScheduler;
  AudioInterruptionService? _audioInterruptionService;
  bool _audioInterruptionStarted = false;
  late final ProviderSubscription<double> _energySubscription;
  late final ProviderSubscription<LearningState> _learningSubscription;
  late final ProviderSubscription<AppView> _viewSubscription;
  late final ProviderSubscription<bool> _networkOnlineSubscription;
  final Set<int> _initializedTabIndexes = <int>{};
  bool _savingCurrentState = false;
  bool get _isFlutterTestBinding {
    final String bindingType = WidgetsBinding.instance.runtimeType.toString();
    return bindingType.contains('TestWidgetsFlutterBinding');
  }

  void _runBackgroundTask(String label, Future<void> Function() task) {
    unawaited(runGuardedBackgroundTask(label: label, task: task));
  }

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
      _initializedTabIndexes.add(_tabIndexForView(next));
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
    });
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

  void _initializeRuntimeServices() {
    _dataHygieneScheduler ??= ref.read(dataHygieneSchedulerProvider);
    _audioInterruptionService ??= ref.read(audioInterruptionServiceProvider);
    if (_isFlutterTestBinding) {
      return;
    }
    _dataHygieneScheduler!.start();
    if (_audioInterruptionStarted) {
      return;
    }
    _audioInterruptionStarted = true;
    _runBackgroundTask(
      'audio interruption startup',
      _startAudioInterruptionService,
    );
  }

  Future<void> _startAudioInterruptionService() async {
    try {
      await _audioInterruptionService!.start(
        onInterruptionBegin: () => runGuardedBackgroundTask(
          label: 'interrupted voice playback shutdown',
          task: _stopVoicePlayback,
        ),
        // A wired headset's removal doesn't affect the device's own mic, so
        // only TTS needs to stop here; otherwise it routes to the speaker.
        onBecomingNoisy: () => runGuardedBackgroundTask(
          label: 'noisy-route voice playback shutdown',
          task: () => ref.read(voiceServiceProvider).stop(),
        ),
      );
    } on Object {
      _audioInterruptionStarted = false;
      rethrow;
    }
  }

  /// Routes a notification tap that arrived while the app was running.
  void _onNotificationTapped() {
    final String? payload = NotificationScheduler.tappedPayloadListenable.value;
    if (payload == null || !mounted) {
      return;
    }
    NotificationScheduler.tappedPayloadListenable.value = null;
    _routeNotificationPayload(payload);
  }

  /// Routes a cold launch that came from a notification tap.
  Future<void> _handleNotificationLaunch() async {
    final String? payload = await NotificationScheduler()
        .consumeLaunchPayload();
    if (payload == null || !mounted) {
      return;
    }
    _routeNotificationPayload(payload);
  }

  /// Maps a notification payload (the domain notification id) to a screen.
  ///
  /// Ids are namespaced by the services that create them; anything
  /// unrecognised falls back to the notifications list rather than being
  /// dropped, which is what happened before — no response handler existed at
  /// all, so a tap only ever opened the app on whatever tab it was last on.
  void _routeNotificationPayload(String payload) {
    String logicalPayload = payload;
    final ({String accountScope, String notificationId})? scoped =
        NotificationScheduler.parseAccountPayload(payload);
    if (scoped != null) {
      final scope = ref.read(accountStorageScopeProvider);
      final String? accountId = scope.isWritable ? scope.rawUserId : null;
      if (accountId == null ||
          AccountDataRegistry.accountDigest(accountId) != scoped.accountScope) {
        return;
      }
      logicalPayload = scoped.notificationId;
    } else if (payload.trimLeft().startsWith('{')) {
      return;
    }

    if (logicalPayload.startsWith('goal_reminder_')) {
      _goToView(AppView.goals);
      return;
    }
    if (logicalPayload.startsWith('daily_planning_reminder')) {
      _goToView(AppView.timeline);
      return;
    }
    if (logicalPayload.startsWith('habit_reminder')) {
      _goToView(AppView.creator);
      return;
    }
    if (logicalPayload.startsWith('reflection_reminder')) {
      _goToView(AppView.timeline);
      return;
    }
    if (logicalPayload.startsWith('streak_break_recovery_')) {
      _goToView(AppView.progression);
      return;
    }
    _goToView(AppView.timeline);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationScheduler.tappedPayloadListenable.removeListener(
      _onNotificationTapped,
    );
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
        _systemScheduler.shutdown();
        _dataHygieneScheduler?.shutdown();
        _runBackgroundTask('voice playback shutdown', _stopVoicePlayback);
        _runBackgroundTask('lifecycle recovery save', _saveCurrentState);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
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
        if (!_isFlutterTestBinding) {
          _initializeRuntimeServices();
          _systemScheduler.resume();
        }
        _syncAppFlowToRouteView(widget.initialView);
        break;
    }
  }

  Future<void> _stopVoicePlayback() async {
    if (!mounted) {
      return;
    }
    try {
      await ref.read(voiceServiceProvider).stop();
    } on Object {
      // Never let a TTS engine failure interfere with lifecycle handling.
    }
    try {
      // An open mic capture must not survive the app being backgrounded.
      await ref.read(voiceControllerProvider.notifier).stopListening();
    } on Object {
      // Never let an STT engine failure interfere with lifecycle handling.
    }
  }

  Future<void> _saveCurrentState() async {
    if (!mounted || _savingCurrentState) {
      return;
    }
    _savingCurrentState = true;
    try {
      final AppView view = widget.initialView;
      await ref.read(appRecoveryProvider).saveState(lastRoute: view.name);
      _runBackgroundTask('daily metrics upload', _pushDailyMetrics);
    } finally {
      _savingCurrentState = false;
    }
  }

  Future<void> _pushDailyMetrics() async {
    if (!mounted) {
      return;
    }
    final accumulator = ref.read(localMetricsAccumulatorProvider);
    final Map<String, dynamic> snapshot = await accumulator.snapshot();
    await ref.read(globalAggregationServiceProvider).push(snapshot);
  }

  void _syncAppFlowToRouteView(AppView view) {
    _initializedTabIndexes.add(_tabIndexForView(view));
    if (ref.read(appFlowProvider) != view) {
      ref.read(appFlowProvider.notifier).show(view);
    }
  }

  void _restoreDefaultLaunchTab() {
    final int? restoredTab = _preferenceService.getLastOpenedTab();
    final AppView restoredView =
        restoredTab == null || restoredTab < 0 || restoredTab > 3
        ? AppView.nexus
        : _viewForTabIndex(restoredTab);
    _goToView(restoredView);
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

  void _triggerCloudSyncReplay() {
    if (!mounted || !Env.enableCloudSync) {
      return;
    }
    ref.invalidate(replayOfflineQueueProvider);
    ref.invalidate(syncToCloudProvider);
    ref.invalidate(offlineQueueCountProvider);
  }

  int _tabIndexForView(AppView view) {
    return switch (view) {
      AppView.nexus => 0,
      AppView.trajectoryEngine => 1,
      AppView.timeline => 2,
      AppView.profile => 3,
      _ => 0,
    };
  }

  AppView _viewForTabIndex(int index) {
    return switch (index) {
      1 => AppView.trajectoryEngine,
      2 => AppView.timeline,
      3 => AppView.profile,
      _ => AppView.nexus,
    };
  }

  void _onTabSelected(int index) {
    _initializedTabIndexes.add(index);
    _runBackgroundTask(
      'primary tab preference save',
      () => _preferenceService.setLastOpenedTab(index),
    );
    _goToView(_viewForTabIndex(index));
  }

  Widget _buildTabbedBody(int tabIndex) {
    Widget tabAt(int index) {
      if (!_initializedTabIndexes.contains(index)) {
        return const SizedBox.shrink();
      }
      final Widget tab = switch (index) {
        1 => const TrajectoryEngineScreen(),
        2 => const TimelineScreen(),
        3 => const ProfileScreen(),
        _ => const NexusScreen(),
      };
      final bool isActive = index == tabIndex;
      return TickerMode(
        enabled: isActive,
        child: ExcludeFocus(excluding: !isActive, child: tab),
      );
    }

    return IndexedStack(
      index: tabIndex,
      children: <Widget>[tabAt(0), tabAt(1), tabAt(2), tabAt(3)],
    );
  }

  Color _navigationAccent(int index) {
    return switch (index) {
      1 || 3 => AppColors.neonViolet,
      _ => AppColors.neonCyan,
    };
  }

  Widget _destinationIcon({
    required _PrimaryDestination destination,
    required bool selected,
    required Color accent,
    double size = 24,
  }) {
    return SvgPicture.asset(
      destination.assetPath,
      width: size,
      height: size,
      excludeFromSemantics: true,
      colorFilter: ColorFilter.mode(
        selected ? accent : const Color(0xFFA8B5CA),
        BlendMode.srcIn,
      ),
    );
  }

  Widget _buildPhoneDestination(int index, int currentIndex) {
    final _PrimaryDestination destination = _primaryDestinations[index];
    final bool selected = index == currentIndex;
    final Color accent = _navigationAccent(index);

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: destination.label,
        child: Tooltip(
          message: destination.label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _onTabSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.all(2),
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? accent.withValues(alpha: 0.38)
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _destinationIcon(
                      destination: destination,
                      selected: selected,
                      accent: accent,
                      size: 25,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        color: selected ? accent : const Color(0xFFA8B5CA),
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneNavigation(int currentIndex) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: TemporalGlassSurface(
        padding: const EdgeInsets.all(4),
        opacity: 0.94,
        blur: 18,
        child: SizedBox(
          height: 64,
          child: Row(
            children: <Widget>[
              for (int index = 0; index < _primaryDestinations.length; index++)
                _buildPhoneDestination(index, currentIndex),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRailDestination({
    required int index,
    required int currentIndex,
    required bool extended,
  }) {
    final _PrimaryDestination destination = _primaryDestinations[index];
    final bool selected = index == currentIndex;
    final Color accent = _navigationAccent(index);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _onTabSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: 56,
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: extended ? 12 : 8),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.38)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: <Widget>[
                  _destinationIcon(
                    destination: destination,
                    selected: selected,
                    accent: accent,
                    size: 26,
                  ),
                  if (extended) ...<Widget>[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? accent : const Color(0xFFA8B5CA),
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRailMapAction({required bool extended}) {
    return Semantics(
      button: true,
      label: 'Open navigation map',
      child: Tooltip(
        message: 'Open navigation map',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _showNavigationMap,
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: extended ? 12 : 8),
                child: Row(
                  mainAxisAlignment: extended
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.map_outlined,
                      size: 26,
                      color: Color(0xFFA8B5CA),
                    ),
                    if (extended) ...<Widget>[
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Navigation map',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFA8B5CA),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationRail({
    required int currentIndex,
    required bool extended,
  }) {
    final double width = extended ? 224 : 72;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: TemporalGlassSurface(
          width: width,
          padding: const EdgeInsets.all(8),
          opacity: 0.94,
          blur: 18,
          child: SafeArea(
            child: Column(
              children: <Widget>[
                const SizedBox(height: 4),
                for (
                  int index = 0;
                  index < _primaryDestinations.length;
                  index++
                ) ...<Widget>[
                  _buildRailDestination(
                    index: index,
                    currentIndex: currentIndex,
                    extended: extended,
                  ),
                  if (index < _primaryDestinations.length - 1)
                    const SizedBox(height: 8),
                ],
                const Spacer(),
                Divider(
                  height: 17,
                  color: AppColors.panelBorder.withValues(alpha: 0.52),
                ),
                _buildRailMapAction(extended: extended),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneMapAction() {
    return TemporalGlassSurface(
      width: AppSizes.touchTarget,
      padding: EdgeInsets.zero,
      opacity: 0.94,
      blur: 18,
      child: SizedBox.square(
        dimension: AppSizes.touchTarget,
        child: IconButton(
          tooltip: 'Open navigation map',
          onPressed: _showNavigationMap,
          icon: const Icon(Icons.map_outlined),
          color: AppColors.neonCyan,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(AppSizes.touchTarget),
            maximumSize: const Size.square(AppSizes.touchTarget),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryShell(int tabIndex) {
    final Widget tabbedBody = _buildTabbedBody(tabIndex);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 600) {
          return Scaffold(
            backgroundColor: AppColors.background,
            floatingActionButton: _buildPhoneMapAction(),
            body: tabbedBody,
            bottomNavigationBar: _buildPhoneNavigation(tabIndex),
          );
        }

        final bool extended = constraints.maxWidth >= 1024;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildNavigationRail(currentIndex: tabIndex, extended: extended),
              Expanded(child: tabbedBody),
            ],
          ),
        );
      },
    );
  }

  void _showNavigationMap() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (BuildContext context) {
        Widget navItem(
          String title,
          String subtitle,
          IconData icon,
          AppView target,
        ) {
          final bool selected = target == widget.initialView;
          return ListTile(
            minVerticalPadding: 8,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            selected: selected,
            selectedColor: AppColors.neonCyan,
            selectedTileColor: AppColors.neonCyan.withValues(alpha: 0.08),
            leading: Icon(
              icon,
              color: selected ? AppColors.neonCyan : const Color(0xFFA8B5CA),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: selected ? AppColors.neonCyan : Colors.white,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFFA8B5CA),
                letterSpacing: 0,
                height: 1.3,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFA8B5CA),
            ),
            onTap: () {
              Navigator.of(context).pop();
              _goToView(target);
            },
          );
        }

        final double maxHeight = MediaQuery.sizeOf(context).height * 0.86;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Center(
              heightFactor: 1,
              child: TemporalGlassSurface(
                width: 560,
                padding: EdgeInsets.zero,
                opacity: 0.96,
                blur: 20,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
                          child: Row(
                            children: <Widget>[
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Navigation Map',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Core first, advanced when needed.',
                                      style: TextStyle(
                                        color: Color(0xFFA8B5CA),
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close navigation map',
                                onPressed: () => Navigator.of(context).pop(),
                                constraints: const BoxConstraints.tightFor(
                                  width: AppSizes.touchTarget,
                                  height: AppSizes.touchTarget,
                                ),
                                icon: const Icon(Icons.close_rounded),
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: AppColors.panelBorder.withValues(alpha: 0.52),
                        ),
                        Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                            children: <Widget>[
                              navItem(
                                'Nexus',
                                'Connected planning home',
                                Icons.hub_outlined,
                                AppView.nexus,
                              ),
                              navItem(
                                'Trajectory Engine',
                                'Future scenarios and execution',
                                Icons.alt_route_rounded,
                                AppView.trajectoryEngine,
                              ),
                              navItem(
                                'Timeline',
                                'Decision memory and context history',
                                Icons.view_timeline_outlined,
                                AppView.timeline,
                              ),
                              navItem(
                                'Profile',
                                'Identity and progression',
                                Icons.person_outline_rounded,
                                AppView.profile,
                              ),
                              Divider(
                                color: AppColors.panelBorder.withValues(
                                  alpha: 0.42,
                                ),
                              ),
                              navItem(
                                'Creator',
                                'Turn intention into connected action',
                                Icons.add_task_rounded,
                                AppView.creator,
                              ),
                              navItem(
                                'Smart Planner',
                                'Reconcile constraints into a next move',
                                Icons.event_note_outlined,
                                AppView.smartPlanner,
                              ),
                              navItem(
                                'SI Console',
                                'Turn context into a decision brief',
                                Icons.psychology_alt_outlined,
                                AppView.console,
                              ),
                              navItem(
                                'Progression',
                                'See capabilities built through action',
                                Icons.trending_up_rounded,
                                AppView.progression,
                              ),
                              navItem(
                                'Settings',
                                'Preferences and controls',
                                Icons.settings_outlined,
                                AppView.settings,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppView view = widget.initialView;
    final int tabIndex = _tabIndexForView(view);
    _initializedTabIndexes.add(tabIndex);

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

        SystemNavigator.pop();
      },
      child: OfflineBanner(child: body),
    );
  }
}
