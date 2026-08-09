import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/deep_link_service.dart';
import 'package:fantastic_guacamole/app/router/navigation_policy.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/config/app_config.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/feature_flags_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/theme_provider.dart';
import 'package:fantastic_guacamole/theme/theme.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_overlay.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_provider.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_state.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:fantastic_guacamole/ui/widgets/error_boundary_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key, this.startupError});

  final String? startupError;

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  GoRouter? _router;
  bool _activationFinalizationInFlight = false;
  final Set<String> _handledDeepLinks = <String>{};
  final Set<String> _handledNotificationPayloads = <String>{};
  String? _lastTrackedLocation;

  @override
  void initState() {
    super.initState();
    NotificationScheduler.notificationPayloadListenable.addListener(
      _handleNotificationPayloadChange,
    );
  }

  void _attachRouterListener(GoRouter router) {
    if (identical(_router, router)) {
      return;
    }
    _router?.routerDelegate.removeListener(_trackRouteChange);
    _router = router;
    router.routerDelegate.addListener(_trackRouteChange);
    _trackRouteChange();
  }

  @override
  void dispose() {
    NotificationScheduler.notificationPayloadListenable.removeListener(
      _handleNotificationPayloadChange,
    );
    _router?.routerDelegate.removeListener(_trackRouteChange);
    super.dispose();
  }

  void _handleNotificationPayloadChange() {
    final GoRouter? router = _router;
    if (router != null) {
      _handlePendingNotificationTap(router);
    }
  }

  void _trackRouteChange() {
    final GoRouter? router = _router;
    if (router == null) {
      return;
    }

    String location = '';

    try {
      location = router.state.matchedLocation;
    } on StateError {
      // GoRouter can briefly have no matched route during initial widget-test boot.
      return;
    }

    if (location.trim().isEmpty) {
      return;
    }

    if (location == _lastTrackedLocation) {
      return;
    }

    _lastTrackedLocation = location;
    unawaited(AppAnalytics.trackScreen(location));
  }

  @override
  Widget build(BuildContext context) {
    final themeEntity = ref.watch(currentThemeProvider).asData?.value;
    final String startupMessage = widget.startupError?.trim() ?? '';
    final bool showQaDiagnostics = ref
        .watch(intelligenceStateProvider)
        .flags
        .testerFullAccess;
    final RemoteAnnouncement? remoteAnnouncement = ref
        .watch(remoteAnnouncementProvider)
        .asData
        ?.value;
    ref.watch(firebaseSupabaseBridgeProvider);
    final String startupBannerMessage = _startupBannerMessage(
      startupMessage,
      showQaDiagnostics: showQaDiagnostics,
    );
    final GoRouter router = ref.watch(appRouterProvider);

    ref.listen<AsyncValue<DeepLinkState>>(deepLinkStateProvider, (
      AsyncValue<DeepLinkState>? _,
      AsyncValue<DeepLinkState> next,
    ) {
      final Uri? uri = next.asData?.value.latestUri;
      if (uri == null) {
        return;
      }
      _handleDeepLink(uri, router);
    });

    ref.listen<AsyncValue<MissionState>>(missionStateProvider, (
      AsyncValue<MissionState>? _,
      AsyncValue<MissionState> next,
    ) {
      final MissionState? missionState = next.asData?.value;
      if (missionState == null || !missionState.finished) {
        return;
      }
      unawaited(_finalizeMissionZeroActivation());
    });

    _attachRouterListener(router);
    _handlePendingNotificationTap(router);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppConfig.fromEnv().appName,
      theme: (themeEntity?.isDark ?? true) ? appTheme : appLightTheme,
      routerConfig: router,
      builder: (context, child) {
        final Widget appChild = ErrorBoundary(
          child: Stack(
            children: <Widget>[
              child ?? const SizedBox.shrink(),
              const MissionOverlay(),
            ],
          ),
        );

        if (startupBannerMessage.isEmpty &&
            !showQaDiagnostics &&
            !_showRemoteAnnouncement(remoteAnnouncement)) {
          return appChild;
        }

        return Stack(
          children: [
            appChild,
            if (startupBannerMessage.isNotEmpty)
              IgnorePointer(
                // Keep diagnostics visible without blocking taps on page controls.
                ignoring: true,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    minimum: const EdgeInsets.all(16),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          startupBannerMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_showRemoteAnnouncement(remoteAnnouncement) &&
                remoteAnnouncement != null)
              Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  minimum: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _announcementBackground(
                          remoteAnnouncement.level,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (remoteAnnouncement.hasTitle)
                            Text(
                              remoteAnnouncement.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (remoteAnnouncement.hasTitle)
                            const SizedBox(height: 4),
                          Text(
                            remoteAnnouncement.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (showQaDiagnostics)
              Align(
                alignment: Alignment.topRight,
                child: SafeArea(
                  minimum: const EdgeInsets.all(12),
                  child: FloatingActionButton.small(
                    heroTag: 'qa_diagnostics_fab',
                    backgroundColor: Colors.black.withValues(alpha: 0.72),
                    onPressed: _showDiagnosticsSheet,
                    child: const Icon(
                      Icons.bug_report_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _finalizeMissionZeroActivation() async {
    if (_activationFinalizationInFlight) {
      return;
    }

    final OnboardingStatus onboardingStatus = ref.read(
      onboardingStatusProvider,
    );
    if (onboardingStatus == OnboardingStatus.complete) {
      return;
    }

    _activationFinalizationInFlight = true;
    try {
      await SharedPrefsService.saveBool(onboardingCompleteStorageKey, true);
      await SharedPrefsService.saveInt(
        onboardingContentVersionStorageKey,
        onboardingContentVersion,
      );
      await SharedPrefsService.saveInt(onboardingStepStorageKey, 0);
      await SharedPrefsService.save(
        onboardingCanonicalStateStorageKey,
        jsonEncode(
          buildOnboardingCanonicalStatePayload(
            complete: true,
            version: onboardingContentVersion,
          ),
        ),
      );
      await SharedPrefsService.saveBool(
        creatorFirstItemCreatedStorageKey,
        true,
      );
      await SharedPrefsService.saveBool(
        timelineFirstActionCompletedStorageKey,
        true,
      );

      if (!mounted) {
        return;
      }

      ref.read(onboardingCompleteProvider.notifier).set(true);
      ref
          .read(onboardingStatusProvider.notifier)
          .set(OnboardingStatus.complete);
      ref.read(creatorFirstItemCreatedProvider.notifier).set(true);
      ref.read(timelineFirstActionCompletedProvider.notifier).set(true);

      if (GoRouter.maybeOf(context) != null) {
        context.go(RoutePaths.home);
      }
    } finally {
      _activationFinalizationInFlight = false;
    }
  }

  bool _showRemoteAnnouncement(RemoteAnnouncement? announcement) {
    if (announcement == null) {
      return false;
    }
    return announcement.enabled && announcement.hasContent;
  }

  Color _announcementBackground(String level) {
    switch (level.trim().toLowerCase()) {
      case 'warning':
      case 'warn':
        return Colors.orange.withValues(alpha: 0.24);
      case 'error':
      case 'critical':
        return Colors.redAccent.withValues(alpha: 0.26);
      default:
        return Colors.blueAccent.withValues(alpha: 0.24);
    }
  }

  void _handleDeepLink(Uri uri, GoRouter router) {
    final String deepLinkKey = uri.toString();

    if (_handledDeepLinks.contains(deepLinkKey)) {
      return;
    }

    _handledDeepLinks.add(deepLinkKey);

    final String location = resolveDeepLinkLocation(uri);
    if (location.isEmpty) {
      return;
    }

    String currentUri = '';

    try {
      currentUri = router.state.uri.toString();
    } on StateError {
      currentUri = '';
    }

    if (currentUri == location) {
      return;
    }

    // Deep links are handled automatically without direct user interaction.
    // Use replace to avoid creating a synthetic browser history entry.
    router.replace<void>(location);
  }

  String _startupBannerMessage(
    String startupMessage, {
    required bool showQaDiagnostics,
  }) {
    if (startupMessage.trim().isEmpty) {
      return '';
    }
    if (showQaDiagnostics) {
      return startupMessage;
    }
    return 'App started in limited mode. Some services may be unavailable.';
  }

  void _showDiagnosticsSheet() {
    final NavigatorState? navigatorState =
        _router?.routerDelegate.navigatorKey.currentState;
    if (navigatorState == null) {
      return;
    }

    showModalBottomSheet<void>(
      context: navigatorState.context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF050D1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Text(
                    'QA Diagnostics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: ValueListenableBuilder<List<String>>(
                    valueListenable: RuntimeDiagnostics.entries,
                    builder: (context, entries, _) {
                      if (entries.isEmpty) {
                        return const Center(
                          child: Text(
                            'No diagnostics captured yet.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              entries[index],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handlePendingNotificationTap(GoRouter router) {
    final String? payload =
        NotificationScheduler.consumePendingNotificationPayload();

    if (payload == null || payload.isEmpty) {
      return;
    }

    if (_handledNotificationPayloads.contains(payload)) {
      return;
    }

    _handledNotificationPayloads.add(payload);

    final String location = resolveNotificationPayloadLocation(payload);
    if (location.isEmpty) {
      return;
    }

    String currentUri = '';

    try {
      currentUri = router.state.uri.toString();
    } on StateError {
      currentUri = '';
    }

    if (currentUri == location) {
      return;
    }

    router.replace<void>(location);
  }
}
