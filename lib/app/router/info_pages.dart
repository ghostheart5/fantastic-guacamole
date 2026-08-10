import 'package:fantastic_guacamole/core/debug/diagnostics_context_service.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UnsupportedLinkPage extends StatelessWidget {
  const UnsupportedLinkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link unavailable')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'This link is not supported by this version of ChronoSpark.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(RoutePaths.home),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
            'Official support page: ${AppUrls.support}\n'
            'If the page is unavailable, use the developer contact shown on the ChronoSpark Google Play listing.\n\n'
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
        ],
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About ChronoSpark')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('ChronoSpark', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'An adaptive planner built for focus, momentum, and reflective execution.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          const _Section(
            title: 'What It Does',
            body:
                'ChronoSpark combines tasks, planning, logs, and AI-assisted strategy in one system so you can execute consistently without losing context.',
          ),
          const _Section(
            title: 'Core Surfaces',
            body:
                'Home for quick direction, Forecast for forward planning, Logs for recent activity, and Profile for identity and progression. Deeper features like Plan, Creator, Smart Planner, Flowmap, Goals, Memories, Soul Map, and Timeline expand capability when needed.',
          ),
          const _Section(
            title: 'Guiding Principle',
            body:
                'Reduce friction between intent and action. Keep planning lightweight, execution clear, and reflection actionable.',
          ),
          const _Section(
            title: 'Privacy and Support',
            body:
                'Official privacy policy: ${AppUrls.privacy}. Terms: ${AppUrls.terms}. Support page: ${AppUrls.support}.',
          ),
          const _Section(
            title: 'Voice Features',
            body:
                'Microphone access powers optional voice-to-text in coaching and the SI console. Audio is used only after you start a voice action and remains off during normal planning flows.',
          ),
        ],
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
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(body, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
