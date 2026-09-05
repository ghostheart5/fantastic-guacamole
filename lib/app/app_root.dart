import 'dart:async';
import 'package:fantastic_guacamole/app/startup/startup_notice_layout.dart';

import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/app_route_registry.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/app/router/deep_link_service.dart';
import 'package:fantastic_guacamole/app/router/route_access_policy.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/config/app_config.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/state/providers/feature_flags_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
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

@visibleForTesting
class DeepLinkEventDeduplicator {
  DeepLinkState? _lastHandledEvent;

  void handleIfNew(DeepLinkState event, void Function(Uri uri) onHandle) {
    final Uri? uri = event.latestUri;
    if (uri == null || identical(_lastHandledEvent, event)) {
      return;
    }

    _lastHandledEvent = event;
    onHandle(uri);
  }
}

const String _authCallbackTypeQueryParameter = 'type';

@visibleForTesting
final accountDataLockActionsProvider = Provider<AccountDataLockActions>((
  Ref ref,
) {
  return AccountDataLockActions(
    claimPreservedData: () => ref
        .read(authSessionBoundaryCoordinatorProvider)
        .claimPreservedDataForCurrentAccount(),
    clearPreservedData: () => ref
        .read(authSessionBoundaryCoordinatorProvider)
        .clearPreservedDataForCurrentAccount(),
    signOut: () => ref.read(authServiceProvider).signOut(),
  );
});

@visibleForTesting
final class AccountDataLockActions {
  const AccountDataLockActions({
    required this.claimPreservedData,
    required this.clearPreservedData,
    required this.signOut,
  });

  final Future<void> Function() claimPreservedData;
  final Future<void> Function() clearPreservedData;
  final Future<void> Function() signOut;
}

void _observeAppFuture<T>(
  Future<T> future, {
  required String category,
  required String message,
}) {
  unawaited(
    future.then<void>(
      (T _) {},
      onError: (Object error, StackTrace stackTrace) {
        Logger.errorCategory(category, message, error, stackTrace);
      },
    ),
  );
}

@visibleForTesting
String resolveExternalDeepLinkLocation(Uri uri) {
  final String appPath = _normalizeExternalAppPath(uri.path);
  if (appPath.isEmpty) {
    return '';
  }

  if (appPath == '/app/auth/callback') {
    final String type =
        (_singleAllowedInputParameter(uri, _authCallbackTypeQueryParameter) ??
                '')
            .toLowerCase();
    final String mode = switch (type) {
      'recovery' => 'recovery',
      'signup' || 'email_change' || 'invite' => 'verify-email',
      _ => 'auth-callback',
    };
    final String? returnTo = _sanitizeReturnTo(
      _singleAllowedInputParameter(
        uri,
        RouteAccessPolicy.returnToQueryParameter,
      ),
    );
    final Map<String, String> queryParameters = <String, String>{'mode': mode};
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
  final AppRouteDefinition? route = AppRouteRegistry.routeForExternalSlug(leaf);
  if (route == null) {
    return '';
  }
  return _sanitizedRouteLocation(
    route.path,
    uri,
    allowSavedTabRestore: route.allowSavedTabRestore,
  );
}

String _sanitizedRouteLocation(
  String route,
  Uri source, {
  bool allowSavedTabRestore = false,
}) {
  final Map<String, String> queryParameters = <String, String>{};
  final List<String>? restoreValues =
      source.queryParametersAll[restoreSavedTabQueryParameter];
  final String fragment = source.fragment.trim();
  final List<String>? fragmentRestoreValues = fragment.isEmpty
      ? <String>[]
      : _fragmentValuesForKey(fragment, restoreSavedTabQueryParameter);
  if (allowSavedTabRestore &&
      restoreValues != null &&
      restoreValues.length == 1 &&
      restoreValues.single == 'true' &&
      fragmentRestoreValues != null &&
      fragmentRestoreValues.isEmpty) {
    queryParameters[restoreSavedTabQueryParameter] = 'true';
  }
  return Uri(
    path: route,
    queryParameters: queryParameters.isEmpty ? null : queryParameters,
  ).toString();
}

String? _sanitizeReturnTo(String? rawReturnTo) {
  final String? validated = RouteAccessPolicy.validatedReturnTo(rawReturnTo);
  if (validated == null) {
    return null;
  }
  final Uri candidate = Uri.parse(validated);
  if (!AppRouteRegistry.isExternallyReachablePath(candidate.path)) {
    return null;
  }
  return _sanitizedRouteLocation(
    candidate.path,
    candidate,
    allowSavedTabRestore: candidate.path == RoutePaths.nexus,
  );
}

String? _singleAllowedInputParameter(Uri uri, String key) {
  final List<String> values = <String>[...?uri.queryParametersAll[key]];
  final String fragment = uri.fragment.trim();
  if (fragment.isNotEmpty) {
    final List<String>? fragmentValues = _fragmentValuesForKey(fragment, key);
    if (fragmentValues == null) {
      return null;
    }
    values.addAll(fragmentValues);
  }
  return values.length == 1 ? values.single : null;
}

List<String>? _fragmentValuesForKey(String fragment, String key) {
  final List<String> values = <String>[];
  for (final String segment in fragment.split('&')) {
    if (segment.isEmpty) {
      continue;
    }
    final int separator = segment.indexOf('=');
    final String rawKey = separator < 0
        ? segment
        : segment.substring(0, separator);
    final String rawValue = separator < 0
        ? ''
        : segment.substring(separator + 1);
    try {
      if (Uri.decodeQueryComponent(rawKey) == key) {
        values.add(Uri.decodeQueryComponent(rawValue));
      }
    } on FormatException {
      return null;
    }
  }
  return values;
}

String _normalizeExternalAppPath(String path) {
  if (path == '/app' || path == '/app/' || path.startsWith('/app/')) {
    return path;
  }
  final int appStart = path.indexOf('/app');
  if (appStart >= 0) {
    return path.substring(appStart);
  }
  return '';
}

class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({
    super.key,
    this.startupError,
    this.productionReadinessBlocked = false,
  });

  final String? startupError;
  final bool productionReadinessBlocked;

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  GoRouter? _router;
  final DeepLinkEventDeduplicator _deepLinkEvents = DeepLinkEventDeduplicator();

  @override
  Widget build(BuildContext context) {
    if (widget.productionReadinessBlocked) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppConfig.fromEnv().appName,
        theme: appTheme,
        home: const _ProductionReadinessLock(),
      );
    }

    final themeEntity = ref.watch(currentThemeProvider).asData?.value;
    final AuthSessionBoundary accountBoundary = ref.watch(
      authSessionBoundaryProvider,
    );
    final String startupMessage = widget.startupError?.trim() ?? '';
    final intelligenceState = ref.watch(intelligenceStateProvider);
    final accountScope = ref.watch(accountStorageScopeProvider);
    final bool showQaDiagnostics = intelligenceState.flags.testerFullAccess;
    if (accountBoundary.isTransitioning ||
        accountBoundary.blockingIssue != null ||
        (intelligenceState.auth.isAuthenticated && !accountScope.isWritable)) {
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
      final DeepLinkState? event = next.asData?.value;
      if (event == null) {
        return;
      }
      _deepLinkEvents.handleIfNew(
        event,
        (Uri uri) => _handleDeepLink(uri, router),
      );
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
            StartupNoticeLayout(message: startupBannerMessage, child: appChild),
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
            if (showQaDiagnostics && startupBannerMessage.isNotEmpty)
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
    final String location = resolveExternalDeepLinkLocation(uri);
    if (location.isEmpty) {
      return;
    }
    final String currentLocation = router.state.matchedLocation;
    if (currentLocation == location) {
      return;
    }
    // Deep links are handled automatically without direct user interaction.
    // Use replace to avoid creating a synthetic browser history entry.
    try {
      _observeAppFuture<Object?>(
        router.replace<Object?>(location),
        category: 'deep_link_navigation',
        message: 'Deep-link navigation failed.',
      );
    } on Exception {
      // A later deep-link event can retry a target rejected by the router.
    }
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

    final Future<void> diagnosticsSheet = showModalBottomSheet<void>(
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
    _observeAppFuture<void>(
      diagnosticsSheet,
      category: 'diagnostics_sheet',
      message: 'Diagnostics sheet presentation failed.',
    );
  }
}

class _ProductionReadinessLock extends StatelessWidget {
  const _ProductionReadinessLock();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050D1A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Semantics(
              liveRegion: true,
              label:
                  'ChronoSpark cannot start safely. Please install the latest version and try again.',
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.shield_outlined,
                    size: 48,
                    color: Color(0xFF00E5FF),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'ChronoSpark cannot start safely',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'This version is missing required setup. To protect your account and data, the app will remain closed. Please install the latest version and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountDataLock extends ConsumerStatefulWidget {
  const _AccountDataLock({required this.boundary});

  final AuthSessionBoundary boundary;

  @override
  ConsumerState<_AccountDataLock> createState() => _AccountDataLockState();
}

class _AccountDataLockState extends ConsumerState<_AccountDataLock> {
  bool _busy = false;
  bool _operationFailed = false;

  @override
  Widget build(BuildContext context) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final AuthSessionBoundary boundary = widget.boundary;
    final String? issue = boundary.canClaimPreservedData
        ? l10n.text(ChronoSparkString.preservedDataIssue)
        : boundary.blockingIssue == null
        ? null
        : l10n.text(ChronoSparkString.accountDataLockIssue);
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
                          key: const Key('account-lock-claim'),
                          onPressed: _busy
                              ? null
                              : () => _runLockAction(
                                  ref
                                      .read(accountDataLockActionsProvider)
                                      .claimPreservedData,
                                ),
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
                          key: const Key('account-lock-clear'),
                          onPressed: _busy
                              ? null
                              : () => _confirmClearPreservedData(context, ref),
                          child: Text(
                            l10n.text(ChronoSparkString.clearPreservedData),
                          ),
                        ),
                      ),
                    ],
                    if (boundary.canRecoverBySigningOut) ...<Widget>[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          key: const Key('account-lock-sign-out'),
                          onPressed: _busy
                              ? null
                              : () => _runLockAction(
                                  ref
                                      .read(accountDataLockActionsProvider)
                                      .signOut,
                                ),
                          icon: const Icon(Icons.logout_rounded),
                          label: Text(
                            l10n.text(
                              ChronoSparkString.signOutAndReturnToLogin,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_busy) ...<Widget>[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        label: l10n.text(
                          ChronoSparkString.accountRecoveryInProgress,
                        ),
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ],
                    if (_operationFailed) ...<Widget>[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          l10n.text(ChronoSparkString.accountRecoveryFailed),
                          key: const Key('account-lock-operation-error'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
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
    await _runLockAction(
      ref.read(accountDataLockActionsProvider).clearPreservedData,
    );
  }

  Future<void> _runLockAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _operationFailed = false;
    });
    try {
      await action();
    } on Object catch (error, stackTrace) {
      Logger.errorCode(
        code: AppDiagnosticCode.accountLockRecoveryActionFailed,
        debugMessage: 'Account lock recovery action failed.',
        exception: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() => _operationFailed = true);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
