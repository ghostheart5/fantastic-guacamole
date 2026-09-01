import 'package:fantastic_guacamole/app/router/route_access_policy.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);

    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgSettingsControlPlane,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              TemporalScreenHeader(
                title: l10n.text(ChronoSparkString.aboutTitle),
                subtitle: l10n.text(ChronoSparkString.aboutSubtitle),
                eyebrow: l10n.text(ChronoSparkString.aboutEyebrow),
                onBack: Navigator.canPop(context)
                    ? () => Navigator.pop(context)
                    : null,
              ),
              const SizedBox(height: 18),
              TemporalGlassSurface(
                child: Column(
                  children: <Widget>[
                    _Section(
                      title: l10n.text(ChronoSparkString.aboutWhatItDoesTitle),
                      body: l10n.text(ChronoSparkString.aboutWhatItDoesBody),
                    ),
                    _Section(
                      title: l10n.text(
                        ChronoSparkString.aboutCoreSurfacesTitle,
                      ),
                      body: l10n.text(ChronoSparkString.aboutCoreSurfacesBody),
                    ),
                    _Section(
                      title: l10n.text(
                        ChronoSparkString.aboutGuidingPrincipleTitle,
                      ),
                      body: l10n.text(
                        ChronoSparkString.aboutGuidingPrincipleBody,
                      ),
                    ),
                    _Section(
                      title: l10n.text(
                        ChronoSparkString.aboutPrivacyAndSupportTitle,
                      ),
                      body: l10n.aboutPrivacyAndSupportBody(
                        privacyUrl: AppUrls.privacy,
                        termsUrl: AppUrls.terms,
                        supportUrl: AppUrls.support,
                        supportEmail: Env.supportEmail,
                      ),
                    ),
                    _Section(
                      title: l10n.text(
                        ChronoSparkString.aboutVoiceFeaturesTitle,
                      ),
                      body: l10n.text(ChronoSparkString.aboutVoiceFeaturesBody),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RouteErrorPage extends StatefulWidget {
  const RouteErrorPage({
    required this.location,
    required this.isAuthenticated,
    required this.welcomeComplete,
    required this.onboardingComplete,
    this.error,
    super.key,
  });

  final String location;
  final bool isAuthenticated;
  final bool welcomeComplete;
  final bool onboardingComplete;
  final Object? error;

  @override
  State<RouteErrorPage> createState() => _RouteErrorPageState();
}

class _RouteErrorPageState extends State<RouteErrorPage> {
  @override
  void initState() {
    super.initState();
    _recordRouterError();
  }

  @override
  void didUpdateWidget(covariant RouteErrorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.location != oldWidget.location ||
        widget.error != oldWidget.error) {
      _recordRouterError();
    }
  }

  void _recordRouterError() {
    final String sanitizedPath = Logger.redactSensitive(
      _safePath(widget.location),
    );
    final String errorType = widget.error?.runtimeType.toString() ?? 'unknown';

    RuntimeDiagnostics.recordState(
      'router',
      message: 'Unresolved route',
      data: <String, Object?>{
        'routeClass': _routeDecision.accessClass.name,
        'path': sanitizedPath,
        'errorType': errorType,
      },
    );
    Logger.errorCategory(
      'Router',
      'Unresolved route: $sanitizedPath (errorType: $errorType)',
    );
  }

  RouteAccessDecision get _routeDecision =>
      RouteAccessPolicy.classify(_safePath(widget.location));

  String get _recoveryRoute {
    final RouteAccessDecision decision = _routeDecision;
    if (decision.allowsSignedOutAccess &&
        decision.accessClass == RouteAccessClass.publicInformation) {
      return RoutePaths.support;
    }
    if (!widget.welcomeComplete) {
      return RoutePaths.onboarding;
    }
    if (decision.requiresAuthentication && !widget.isAuthenticated) {
      return RoutePaths.login;
    }
    if (decision.requiresCompletedOnboarding && !widget.onboardingComplete) {
      return RoutePaths.onboarding;
    }
    return RoutePaths.nexus;
  }

  ChronoSparkString get _recoveryLabel {
    return switch (_recoveryRoute) {
      RoutePaths.login => ChronoSparkString.routerErrorReturnLogin,
      RoutePaths.onboarding => ChronoSparkString.routerErrorReturnOnboarding,
      RoutePaths.support => ChronoSparkString.routerErrorReturnSupport,
      _ => ChronoSparkString.routerErrorReturnNexus,
    };
  }

  static String _safePath(String location) {
    final Uri? parsed = Uri.tryParse(location);
    final String path = parsed?.path ?? location;
    return path.isEmpty ? RoutePaths.nexus : path;
  }

  @override
  Widget build(BuildContext context) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.text(ChronoSparkString.routerErrorTitle)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.text(ChronoSparkString.routerErrorTitle),
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.text(ChronoSparkString.routerErrorBody),
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.go(_recoveryRoute),
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(l10n.text(_recoveryLabel)),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 14),
            Divider(color: theme.colorScheme.primary.withValues(alpha: 0.18)),
          ],
        ),
      ),
    );
  }
}
