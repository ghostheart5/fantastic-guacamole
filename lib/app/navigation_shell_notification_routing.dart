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

  /// Claims a cold launch that came from a notification tap and holds it
  /// until the account is ready (see [_routeHeldLaunchPayload]). Holding
  /// notifies every mounted shell, so the tap is routed even when the shell
  /// that claimed it was replaced while the read was waiting.
  Future<void> _handleNotificationLaunch() async {
    final NotificationScheduler scheduler = NotificationScheduler();
    final String? payload = await scheduler.consumeLaunchPayload();
    if (payload != null) scheduler.holdLaunchPayload(payload);
    _routeHeldLaunchPayload();
  }

  /// Routes the held cold-launch payload once, when account storage is ready
  /// for the signed-in account. Until then it stays held, rather than being
  /// dropped by the account check in [_routeNotificationPayload]; that check
  /// then drops a payload that belongs to another account.
  void _routeHeldLaunchPayload() {
    if (!mounted || !NotificationScheduler().hasHeldLaunchPayload) return;
    _runBackgroundTask('held notification launch routing', () async {
      // Readiness can change during a frame; navigate on the next event turn.
      await Future<void>.delayed(Duration.zero);
      if (!mounted || ref.read(_reminderRecoveryOwnerProvider) == null) return;
      final String? payload = NotificationScheduler().takeHeldLaunchPayload();
      if (payload != null) _routeNotificationPayload(payload);
    });
  }

  /// Maps a notification payload (the domain notification id) to a screen
  /// (see [notificationDestinationFor]). Anything unrecognised falls back to
  /// a tab rather than being dropped.
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

    final NotificationDestination destination = notificationDestinationFor(
      logicalPayload,
    );
    switch (destination) {
      case NotificationDestination.habitCheckIns:
        if (!_canPushFromNotification()) return;
        // Close anything pushed earlier so the list is what shows.
        popToFirstRoute(context);
        unawaited(
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const DailyRhythmsScreen()),
          ),
        );
      case NotificationDestination.reflectionSchedule:
        if (!_canPushFromNotification()) return;
        unawaited(openSchedule(context));
      case NotificationDestination.goals ||
          NotificationDestination.dailyPlanning ||
          NotificationDestination.tasks ||
          NotificationDestination.activity ||
          NotificationDestination.fallback:
        _goToView(destination.view ?? AppView.timeline);
    }
  }

  // External taps can arrive while a mounted shell is being redirected. A
  // pushed screen skips the router's guards, so recheck current admission
  // after the cold-launch await and immediately before push.
  bool _canPushFromNotification() {
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
