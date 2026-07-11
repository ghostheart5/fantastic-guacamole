import 'dart:async';

import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/deep_link_service.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/config/app_config.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/state/providers/feature_flags_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/theme_provider.dart';
import 'package:fantastic_guacamole/theme/theme.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_overlay.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_provider.dart';
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
  static const List<String> _tutorialAssets = <String>[
    'assets/tutorials/home.json',
    'assets/tutorials/tasks.json',
  ];

  GoRouter? _router;
  VoidCallback? _routerListener;
  bool _tutorialAssetsLoaded = false;
  final Set<String> _handledDeepLinks = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_loadTutorialAssetsIfNeeded());
    });
  }

  Future<void> _loadTutorialAssetsIfNeeded() async {
    if (_tutorialAssetsLoaded) {
      return;
    }
    final controller = ref.read(tutorialControllerProvider);
    await controller.loadAssets(_tutorialAssets);
    if (!mounted) {
      return;
    }
    _tutorialAssetsLoaded = true;
  }

  void _attachRouterListener(GoRouter router) {
    if (identical(_router, router)) {
      return;
    }
    if (_router != null && _routerListener != null) {
      _router!.routerDelegate.removeListener(_routerListener!);
    }
    _router = router;
    _routerListener = () {
      if (!mounted || _router == null) {
        return;
      }
      final controller = ref.read(tutorialControllerProvider);
      final String route = _router!.routeInformationProvider.value.uri
          .toString();
      controller.updateRoute(route);
    };
    _router!.routerDelegate.addListener(_routerListener!);
    _routerListener!.call();
  }

  @override
  void dispose() {
    if (_router != null && _routerListener != null) {
      _router!.routerDelegate.removeListener(_routerListener!);
    }
    super.dispose();
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
    final String startupBannerMessage = _startupBannerMessage(
      startupMessage,
      showQaDiagnostics: showQaDiagnostics,
    );
    final GoRouter router = ref.watch(appRouterProvider);
    final tutorialController = ref.watch(tutorialControllerProvider);

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

    _attachRouterListener(router);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppConfig.fromEnv().appName,
      theme: (themeEntity?.isDark ?? true) ? appTheme : appLightTheme,
      routerConfig: router,
      builder: (context, child) {
        final Widget appChild = ErrorBoundary(
          child: TutorialHost(
            controller: tutorialController,
            child: child ?? const SizedBox.shrink(),
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
            if (_showRemoteAnnouncement(remoteAnnouncement))
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
                          remoteAnnouncement!.level,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (remoteAnnouncement.title.trim().isNotEmpty)
                            Text(
                              remoteAnnouncement.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (remoteAnnouncement.title.trim().isNotEmpty)
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
    _handledDeepLinks.add(deepLinkKey);

    final String location = _resolveDeepLinkLocation(uri);
    if (location.isEmpty) {
      return;
    }
    router.go(location);
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
      return '${RoutePaths.login}?mode=$mode';
    }

    if (appPath == '/app' || appPath == '/app/') {
      return RoutePaths.home;
    }

    final String leaf = appPath.substring('/app/'.length);
    return switch (leaf) {
      'home' => RoutePaths.home,
      'plan' => RoutePaths.plan,
      'creator' => RoutePaths.creator,
      'insights' => RoutePaths.insights,
      'settings' => RoutePaths.settings,
      'notifications' => RoutePaths.notifications,
      'support' => RoutePaths.support,
      'privacy' => RoutePaths.privacy,
      'terms' => RoutePaths.terms,
      _ => RoutePaths.home,
    };
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
