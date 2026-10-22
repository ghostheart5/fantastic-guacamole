part of 'navigation_shell.dart';

extension _NavigationShellNotificationRouting on _NavigationShellState {
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
      _goToView(AppView.smartPlanner);
      return;
    }
    if (logicalPayload.startsWith('habit_reminder')) {
      _goToView(AppView.creator);
      return;
    }
    if (logicalPayload.startsWith('reflection_reminder')) {
      if (!_canOpenReflectionSchedule()) return;
      unawaited(openSchedule(context));
      return;
    }
    if (logicalPayload.startsWith('streak_break_recovery_')) {
      _goToView(AppView.progression);
      return;
    }
    _goToView(AppView.timeline);
  }

  // External taps can arrive while a mounted shell is being redirected. Recheck
  // current admission after the cold-launch await and immediately before push.
  bool _canOpenReflectionSchedule() {
    final scope = ref.read(accountStorageScopeProvider);
    final boundary = ref.read(authSessionBoundaryProvider);
    final recovery = ref.read(passwordRecoveryStateProvider).asData?.value;
    return mounted &&
        ref.read(route_guards.authenticatedGuardProvider) &&
        ref.read(route_guards.onboardingWelcomeCompleteGuardProvider) &&
        ref.read(route_guards.onboardingCompleteGuardProvider) &&
        scope.isWritable &&
        boundary.userId == scope.rawUserId &&
        !boundary.isTransitioning &&
        boundary.isStorageReady &&
        !(boundary.blockingIssue?.trim().isNotEmpty ?? false) &&
        recovery != null &&
        !recovery.isPending;
  }
}
