import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Route-aware, event-driven guidance. It offers one state-specific action and
/// never completes an intervention merely because its prompt was tapped.
class AdaptiveGuideOverlay extends ConsumerStatefulWidget {
  const AdaptiveGuideOverlay({super.key});

  @override
  ConsumerState<AdaptiveGuideOverlay> createState() =>
      _AdaptiveGuideOverlayState();
}

class _AdaptiveGuideOverlayState extends ConsumerState<AdaptiveGuideOverlay> {
  bool _expanded = true;

  bool _routeAllowsGuidance(String location) {
    return location.isNotEmpty &&
        location != RoutePaths.onboarding &&
        location != RoutePaths.login &&
        location != RoutePaths.paywall &&
        location != RoutePaths.deleteAccount &&
        location != RoutePaths.privacy &&
        location != RoutePaths.terms;
  }

  @override
  Widget build(BuildContext context) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final bool onboardingComplete = ref.watch(onboardingCompleteProvider);
    final auth = ref.watch(authUserProvider).asData?.value;
    final AuthSessionBoundary boundary = ref.watch(authSessionBoundaryProvider);
    final AdaptiveGuidanceState? guidance = ref
        .watch(adaptiveGuidanceProvider)
        .asData
        ?.value;
    final DailyDecisionIntelligence decision = ref.watch(
      dailyDecisionIntelligenceProvider,
    );
    final GoRouter? router = GoRouter.maybeOf(context);
    final String location =
        router?.routeInformationProvider.value.uri.path ?? '';
    final GuidanceLesson? lesson = guidance?.nextIntervention(
      currentRoute: location,
      decision: decision,
    );
    final bool keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    if (!onboardingComplete ||
        auth == null ||
        boundary.isTransitioning ||
        !boundary.isStorageReady ||
        boundary.blockingIssue != null ||
        boundary.userId != auth.id ||
        guidance == null ||
        lesson == null ||
        keyboardVisible ||
        !_routeAllowsGuidance(location)) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool phone = constraints.maxWidth < 600;
        final double width = phone
            ? constraints.maxWidth
            : constraints.maxWidth < 1024
            ? 440
            : 400;
        final double maxHeight = (constraints.maxHeight - 24).clamp(
          48.0,
          420.0,
        );

        return Align(
          alignment: phone ? Alignment.bottomCenter : Alignment.bottomRight,
          child: SafeArea(
            minimum: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: width,
                minWidth: phone ? 0 : 320,
                maxHeight: maxHeight,
              ),
              child: _expanded
                  ? _ContextGuidanceDock(
                      lesson: lesson,
                      alreadyHere: location == lesson.route,
                      onCollapse: () => setState(() => _expanded = false),
                      onAction: () {
                        setState(() => _expanded = false);
                        if (location != lesson.route) {
                          context.go(lesson.route);
                        }
                      },
                      onDismiss: () => ref
                          .read(adaptiveGuidanceProvider.notifier)
                          .skip(lesson.id),
                    )
                  : Semantics(
                      button: true,
                      label: l10n.text(
                        ChronoSparkString.openContextualGuidance,
                      ),
                      child: FilledButton.tonalIcon(
                        onPressed: () => setState(() => _expanded = true),
                        icon: const Icon(Icons.adjust_rounded),
                        label: Text(
                          l10n.text(ChronoSparkString.contextualGuidance),
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _ContextGuidanceDock extends StatelessWidget {
  const _ContextGuidanceDock({
    required this.lesson,
    required this.alreadyHere,
    required this.onCollapse,
    required this.onAction,
    required this.onDismiss,
  });

  final GuidanceLesson lesson;
  final bool alreadyHere;
  final VoidCallback onCollapse;
  final VoidCallback onAction;
  final Future<void> Function() onDismiss;

  @override
  Widget build(BuildContext context) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final String lessonId = lesson.id.name;
    final String title = l10n.guideTitle(lessonId, lesson.title);
    final String body = l10n.guideBody(lessonId, lesson.body);
    final String action = l10n.guideAction(lessonId, lesson.actionLabel);
    return Material(
      color: const Color(0xF208131F),
      elevation: 12,
      shadowColor: const Color(0x6600E5FF),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFF00E5FF), width: 3)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.adjust_rounded,
                    size: 18,
                    color: Color(0xFF00E5FF),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      label:
                          '${l10n.text(ChronoSparkString.contextualGuidance)}: $title',
                      child: Text(
                        l10n
                            .text(ChronoSparkString.contextualGuidance)
                            .toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF00E5FF),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.text(ChronoSparkString.collapseGuidance),
                    onPressed: onCollapse,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(body),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: onAction,
                      child: Text(
                        alreadyHere
                            ? l10n.text(ChronoSparkString.useThisScreen)
                            : action,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: onDismiss,
                      child: Text(l10n.text(ChronoSparkString.notNow)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
