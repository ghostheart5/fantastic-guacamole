part of 'navigation_shell.dart';

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

extension _NavigationShellLifecycle on _NavigationShellState {
  bool get _isFlutterTestBinding {
    final String bindingType = WidgetsBinding.instance.runtimeType.toString();
    return bindingType.contains('TestWidgetsFlutterBinding');
  }

  void _runBackgroundTask(String label, Future<void> Function() task) {
    unawaited(runGuardedBackgroundTask(label: label, task: task));
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
      if (_isPrimaryView(view)) {
        await ref
            .read(appRecoveryProvider)
            .saveState(lastPrimaryViewName: view.name);
      }
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

  void _triggerCloudSyncReplay() {
    if (!mounted || !Env.enableCloudSync) {
      return;
    }
    ref.invalidate(replayOfflineQueueProvider);
    ref.invalidate(syncToCloudProvider);
    ref.invalidate(offlineQueueCountProvider);
  }

  void _scheduleNetworkRecoveryRetry() {
    _networkRetryDebounceTimer?.cancel();
    _networkRetryDebounceTimer = Timer(networkReconnectRetryDebounce, () {
      _networkRetryDebounceTimer = null;
      if (!mounted ||
          ref.read(networkInterfaceAvailabilityProvider) !=
              NetworkInterfaceAvailability.available) {
        return;
      }
      _triggerCloudSyncReplay();
      _runBackgroundTask(
        'subscription authority retry after network interface recovery',
        () => ref.read(entitlementAuthorityRefreshProvider)(force: true),
      );
    });
  }
}
