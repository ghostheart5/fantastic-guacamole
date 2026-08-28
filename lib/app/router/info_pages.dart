import 'package:fantastic_guacamole/app/router/route_access_policy.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/diagnostics_context_service.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'We can help you recover momentum quickly.',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'Best way to get support:\n'
            '1. Open Settings in the app\n'
            '2. Use diagnostics + logs to capture context\n'
            '3. Send your issue summary and what you expected to happen\n\n'
            'Support address: support@chronospark.app\n\n'
            'Include these details for faster help:\n'
            '- Device + OS version\n'
            '- App version\n'
            '- What you tapped before the issue\n'
            '- Screenshot or error text if available',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          FutureBuilder<DiagnosticsContext>(
            future: DiagnosticsContextService.collect(),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<DiagnosticsContext> snapshot,
                ) {
                  final DiagnosticsContext? data = snapshot.data;
                  final String diagnosticsText = data == null
                      ? 'Loading diagnostics context...'
                      : 'Diagnostics context\n'
                            '- App: ${data.appName}\n'
                            '- Version: ${data.appVersionLabel}\n'
                            '- Package: ${data.packageName}\n'
                            '- Platform: ${data.platform}\n'
                            '- OS: ${data.osVersion}\n'
                            '- Device: ${data.model}\n'
                            '- Physical device: ${data.isPhysicalDevice}';
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.22,
                        ),
                      ),
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.34),
                    ),
                    child: Text(
                      diagnosticsText,
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                },
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.22),
              ),
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
            ),
            child: Text(
              'Response targets\n'
              '- Critical outage: same day\n'
              '- Login and billing issues: within 24 hours\n'
              '- General product support: 1-2 business days',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgSettingsControlPlane,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              TemporalScreenHeader(
                title: 'ABOUT CHRONOSPARK',
                subtitle:
                    'An adaptive planner built for clarity, momentum, and reflective execution.',
                eyebrow: 'SYSTEM IDENTITY',
                onBack: Navigator.canPop(context)
                    ? () => Navigator.pop(context)
                    : null,
              ),
              const SizedBox(height: 18),
              const TemporalGlassSurface(
                child: Column(
                  children: <Widget>[
                    _Section(
                      title: 'What It Does',
                      body:
                          'ChronoSpark combines tasks, planning, logs, and AI-assisted strategy in one system so you can execute consistently without losing context.',
                    ),
                    _Section(
                      title: 'Core Surfaces',
                      body:
                          'Nexus for decisions, Trajectory Engine for possible paths, Timeline for history, and Profile for identity and progression. Smart Planner, Creator, SI Console, and Progression add depth when needed.',
                    ),
                    _Section(
                      title: 'Guiding Principle',
                      body:
                          'Reduce friction between intent and action. Keep planning lightweight, execution clear, and reflection actionable.',
                    ),
                    _Section(
                      title: 'Privacy and Support',
                      body:
                          'Official privacy policy: ${AppUrls.privacy}. Terms: ${AppUrls.terms}. Support page: ${AppUrls.support}. Support email: ${Env.supportEmail}.',
                    ),
                    _Section(
                      title: 'Voice Features',
                      body:
                          'Microphone access powers optional voice-to-text in Smart Planner and the SI Console. Audio is used only after you start a voice action and remains off during normal planning flows.',
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
