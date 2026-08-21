import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/app/router/deep_link_service.dart';
import 'package:fantastic_guacamole/app/router/route_access_policy.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/config/app_config.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/state/providers/feature_flags_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_coordinator_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/theme_provider.dart';
import 'package:fantastic_guacamole/theme/theme.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guide_overlay.dart';
import 'package:fantastic_guacamole/ui/widgets/error_boundary_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
  final Set<String> _handledDeepLinks = <String>{};

  @override
  Widget build(BuildContext context) {
    final themeEntity = ref.watch(currentThemeProvider).asData?.value;
    final AuthSessionBoundary accountBoundary = ref.watch(
      authSessionBoundaryProvider,
    );
    final String startupMessage = widget.startupError?.trim() ?? '';
    final bool showQaDiagnostics = ref
        .watch(intelligenceStateProvider)
        .flags
        .testerFullAccess;
    if (accountBoundary.isTransitioning ||
        accountBoundary.blockingIssue != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppConfig.fromEnv().appName,
        supportedLocales: ChronoSparkLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ChronoSparkLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: (themeEntity?.isDark ?? true) ? appTheme : appLightTheme,
        home: _AccountDataLock(boundary: accountBoundary),
      );
    }
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
    _router = router;

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

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppConfig.fromEnv().appName,
      supportedLocales: ChronoSparkLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        ChronoSparkLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: (themeEntity?.isDark ?? true) ? appTheme : appLightTheme,
      routerConfig: router,
      builder: (context, child) {
        final Widget appChild = Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned.fill(
              child: ErrorBoundary(child: child ?? const SizedBox.shrink()),
            ),
            const AdaptiveGuideOverlay(),
          ],
        );

        if (startupBannerMessage.isEmpty &&
            !showQaDiagnostics &&
            !_showRemoteAnnouncement(remoteAnnouncement)) {
          return appChild;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            appChild,
            if (startupBannerMessage.isNotEmpty)
              Align(
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

    final String location = _resolveDeepLinkLocation(uri);
    if (location.isEmpty) {
      return;
    }
    final String currentLocation = router.state.matchedLocation;
    if (currentLocation == location) {
      _handledDeepLinks.add(deepLinkKey);
      return;
    }
    // Deep links are handled automatically without direct user interaction.
    // Use replace to avoid creating a synthetic browser history entry.
    try {
      router.replace<Object?>(location);
      _handledDeepLinks.add(deepLinkKey);
    } on Exception {
      // Do not mark the link handled unless the router accepted the target.
    }
  }

  String _resolveDeepLinkLocation(Uri uri) {
    final String appPath = _normalizeAppPath(uri.path);
    if (appPath.isEmpty) {
      return '';
    }

    final Map<String, String> params = _allLinkParams(uri);

    if (appPath == '/app/auth/callback') {
      final String type = (params['type'] ?? '').toLowerCase();
      final String mode = switch (type) {
        'recovery' => 'recovery',
        'signup' || 'email_change' || 'invite' => 'verify-email',
        _ => 'auth-callback',
      };
      final String? returnTo = RouteAccessPolicy.validatedReturnTo(
        params[RouteAccessPolicy.returnToQueryParameter],
      );
      final Map<String, String> queryParameters = <String, String>{
        'mode': mode,
      };
      if (returnTo != null) {
        queryParameters[RouteAccessPolicy.returnToQueryParameter] = returnTo;
      }
      return Uri(
        path: RoutePaths.login,
        queryParameters: queryParameters,
      ).toString();
    }

    if (appPath == '/app' || appPath == '/app/') {
      return RoutePaths.nexus;
    }

    final String leaf = appPath.substring('/app/'.length);
    final String route = switch (leaf) {
      'home' || 'nexus' => RoutePaths.nexus,
      'plan' => RoutePaths.timeline,
      'creator' => RoutePaths.creator,
      'settings' => RoutePaths.settings,
      'notifications' => RoutePaths.notifications,
      'support' => RoutePaths.support,
      'privacy' => RoutePaths.privacy,
      'terms' => RoutePaths.terms,
      _ => RoutePaths.nexus,
    };
    return _withAllowedLinkParts(route, uri);
  }

  String _withAllowedLinkParts(String route, Uri source) {
    final Map<String, String> query = Map<String, String>.of(
      source.queryParameters,
    )..remove(RouteAccessPolicy.returnToQueryParameter);
    return Uri(
      path: route,
      queryParameters: query.isEmpty ? null : query,
      fragment: source.fragment.isEmpty ? null : source.fragment,
    ).toString();
  }

  String _normalizeAppPath(String path) {
    if (path == '/app' || path == '/app/' || path.startsWith('/app/')) {
      return path;
    }
    final int appStart = path.indexOf('/app');
    if (appStart >= 0) {
      return path.substring(appStart);
    }
    return '';
  }

  Map<String, String> _allLinkParams(Uri uri) {
    final Map<String, String> merged = <String, String>{...uri.queryParameters};
    final String fragment = uri.fragment.trim();
    if (fragment.isNotEmpty) {
      merged.addAll(Uri.splitQueryString(fragment));
    }
    return merged;
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
}

class _AccountDataLock extends ConsumerWidget {
  const _AccountDataLock({required this.boundary});

  final AuthSessionBoundary boundary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final String? issue = boundary.canClaimPreservedData
        ? l10n.text(ChronoSparkString.preservedDataIssue)
        : boundary.blockingIssue;
    return Scaffold(
      backgroundColor: const Color(0xFF050D1A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Semantics(
              liveRegion: true,
              label: issue ?? l10n.text(ChronoSparkString.securingAccountData),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (issue == null) ...<Widget>[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(l10n.text(ChronoSparkString.securingAccountData)),
                  ] else ...<Widget>[
                    const Icon(
                      Icons.lock_person_outlined,
                      size: 48,
                      color: Color(0xFF00E5FF),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      issue,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (boundary.canClaimPreservedData) ...<Widget>[
                      const SizedBox(height: 24),
                      Text(
                        l10n.text(ChronoSparkString.preservedDataBody),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: () => ref
                              .read(authSessionBoundaryCoordinatorProvider)
                              .claimPreservedDataForCurrentAccount(),
                          child: Text(
                            l10n.text(ChronoSparkString.claimPreservedData),
                          ),
                        ),
                      ),
                    ],
                    if (boundary.canClearPreservedData) ...<Widget>[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () =>
                              _confirmClearPreservedData(context, ref),
                          child: Text(
                            l10n.text(ChronoSparkString.clearPreservedData),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearPreservedData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(l10n.text(ChronoSparkString.clearPreservedDataTitle)),
            content: Text(l10n.text(ChronoSparkString.clearPreservedDataBody)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.text(ChronoSparkString.cancel)),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.text(ChronoSparkString.clearPreservedData)),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    await ref
        .read(authSessionBoundaryCoordinatorProvider)
        .clearPreservedDataForCurrentAccount();
  }
}
