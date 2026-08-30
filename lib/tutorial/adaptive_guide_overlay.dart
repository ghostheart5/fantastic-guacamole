import 'dart:async';

import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/creator_draft_provider.dart';
import 'package:fantastic_guacamole/state/providers/creator_handshake_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/tutorial/first_run_tutorial_state.dart';
import 'package:fantastic_guacamole/tutorial/interactive_tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Event-driven guidance rendered as an interactive spotlight over the real
/// controls. Core lessons only advance after real input or persistence.
class AdaptiveGuideOverlay extends ConsumerStatefulWidget {
  const AdaptiveGuideOverlay({super.key});

  @override
  ConsumerState<AdaptiveGuideOverlay> createState() =>
      _AdaptiveGuideOverlayState();
}

class _AdaptiveGuideOverlayState extends ConsumerState<AdaptiveGuideOverlay> {
  final GlobalKey _untargetedLessonKey = GlobalKey(
    debugLabel: 'untargeted-guidance',
  );
  CreatorTutorialStep _creatorStep = CreatorTutorialStep.title;
  GuidanceLessonId? _suppressedLesson;
  bool _completingCreator = false;
  bool _completingTimeline = false;

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
    final bool onboardingComplete = ref.watch(onboardingCompleteProvider);
    final bool interactionPaused = ref.watch(tutorialInteractionPausedProvider);
    final CreatorHandshakeState handshake = ref.watch(creatorHandshakeProvider);
    final auth = ref.watch(authUserProvider).asData?.value;
    final AuthSessionBoundary boundary = ref.watch(authSessionBoundaryProvider);
    final AdaptiveGuidanceState? guidance = ref
        .watch(adaptiveGuidanceProvider)
        .asData
        ?.value;
    final DailyDecisionIntelligence decision = ref.watch(
      dailyDecisionIntelligenceProvider,
    );
    final String? timelineEvidenceTaskId = ref.watch(
      timelineTutorialEvidenceProvider,
    );
    final GoRouter? router = GoRouter.maybeOf(context);
    final String location =
        router?.routeInformationProvider.value.uri.path ?? '';
    final GuidanceLesson? lesson = guidance?.nextIntervention(
      currentRoute: location,
      decision: decision,
    );

    if (!onboardingComplete ||
        interactionPaused ||
        auth == null ||
        boundary.isTransitioning ||
        !boundary.isStorageReady ||
        boundary.blockingIssue != null ||
        boundary.userId != auth.id ||
        guidance == null ||
        lesson == null ||
        !_routeAllowsGuidance(location) ||
        _suppressedLesson == lesson.id) {
      return const SizedBox.shrink();
    }

    if (lesson.id == GuidanceLessonId.createFirstItem ||
        lesson.id == GuidanceLessonId.scheduleFirstItem) {
      if (location != RoutePaths.creator) {
        return _routePrompt(context, lesson);
      }
      return _creatorLesson(context, handshake, lesson);
    }

    if (lesson.id == GuidanceLessonId.reviewTimeline) {
      if (location != RoutePaths.timeline) {
        return _routePrompt(context, lesson);
      }
      return _timelineLesson(context, guidance, timelineEvidenceTaskId);
    }

    return _advancedLesson(context, lesson, location);
  }

  Widget _routePrompt(BuildContext context, GuidanceLesson lesson) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    return InteractiveTutorialOverlay(
      targetKey: _untargetedLessonKey,
      stepLabel: _copy(l10n, 'Next guided action', 'Siguiente acción guiada'),
      title: l10n.guideTitle(lesson.id.name, lesson.title),
      body: l10n.guideBody(lesson.id.name, lesson.body),
      primaryLabel: l10n.guideAction(lesson.id.name, lesson.actionLabel),
      onPrimary: () => context.go(lesson.route),
      secondaryLabel: _copy(l10n, 'Later', 'Más tarde'),
      onSecondary: () => unawaited(
        ref.read(adaptiveGuidanceProvider.notifier).later(lesson.id),
      ),
      allowTargetInteraction: false,
    );
  }

  Widget _creatorLesson(
    BuildContext context,
    CreatorHandshakeState handshake,
    GuidanceLesson lesson,
  ) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final CreatorTutorialDraftState draft = ref.watch(
      creatorTutorialDraftProvider,
    );
    final CreatorTutorialStep activeStep = handshake.isReviewing
        ? CreatorTutorialStep.confirm
        : _creatorStep;
    final _CreatorStepCopy copy = _creatorStepCopy(l10n, activeStep);
    final bool enabled = switch (activeStep) {
      CreatorTutorialStep.title => draft.hasTitle,
      CreatorTutorialStep.priority => draft.hasChosenPriority,
      CreatorTutorialStep.schedule => draft.hasSchedule,
      CreatorTutorialStep.save => true,
      CreatorTutorialStep.confirm =>
        handshake.canConfirm && !_completingCreator,
    };

    return InteractiveTutorialOverlay(
      targetKey: copy.targetKey,
      stepLabel:
          '${_copy(l10n, 'Creator', 'Creador')} ${activeStep.index + 1} ${_copy(l10n, 'of', 'de')} ${CreatorTutorialStep.values.length}',
      title: copy.title,
      body: copy.body,
      primaryLabel: copy.action,
      primaryEnabled: enabled,
      onPrimary: () {
        if (activeStep == CreatorTutorialStep.save) {
          unawaited(ref.read(creatorTutorialFormControllerProvider).submit());
          return;
        }
        if (activeStep == CreatorTutorialStep.confirm) {
          unawaited(_confirmCreatorAndOpenTimeline(context));
          return;
        }
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() {
          _creatorStep = CreatorTutorialStep.values[_creatorStep.index + 1];
        });
      },
      secondaryLabel: _copy(l10n, 'Finish later', 'Terminar más tarde'),
      onSecondary: () => unawaited(
        ref.read(adaptiveGuidanceProvider.notifier).later(lesson.id),
      ),
    );
  }

  Future<void> _confirmCreatorAndOpenTimeline(BuildContext context) async {
    if (_completingCreator) return;
    final CreatorHandshakeState pending = ref.read(creatorHandshakeProvider);
    final bool hasSchedule =
        pending.preview?.selectedOperations.any(
          (CreatorMutationOperation operation) =>
              operation.task.scheduledFor != null,
        ) ??
        false;
    setState(() => _completingCreator = true);
    try {
      final CreatorHandshakeState result = await ref
          .read(creatorHandshakeProvider.notifier)
          .confirm();
      if (result.receipt == null || !mounted) return;
      await ref
          .read(adaptiveGuidanceProvider.notifier)
          .recordCreatorHandshakeReceipt(result.receipt!);
      if (!mounted) return;
      ref.read(creatorTutorialDraftProvider.notifier).reset();
      ref.read(creatorDraftPreviewProvider.notifier).clear();
      setState(() => _creatorStep = CreatorTutorialStep.title);
      if (hasSchedule && context.mounted) {
        context.go(RoutePaths.timeline);
      }
    } finally {
      if (mounted) setState(() => _completingCreator = false);
    }
  }

  Widget _timelineLesson(
    BuildContext context,
    AdaptiveGuidanceState guidance,
    String? timelineEvidenceTaskId,
  ) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final bool hasExpectedReceipt =
        guidance.expectedFirstRunCreatorTaskIds.isNotEmpty;
    final bool hasMatchingEvidence =
        hasExpectedReceipt &&
        timelineEvidenceTaskId != null &&
        guidance.matchesExpectedFirstRunCreatorTask(timelineEvidenceTaskId) &&
        FirstRunTutorialTargets.timelineEvidence.currentContext != null;
    return InteractiveTutorialOverlay(
      targetKey: FirstRunTutorialTargets.timelineEvidence,
      stepLabel: _copy(
        l10n,
        'Optional Creator/Timeline lesson',
        'Lección opcional de Creador/Línea de Tiempo',
      ),
      title: hasMatchingEvidence
          ? _copy(
              l10n,
              'Your saved task is now on Timeline',
              'Tu tarea guardada ya está en Línea de Tiempo',
            )
          : _copy(
              l10n,
              'Waiting for saved-task evidence',
              'Esperando evidencia de la tarea guardada',
            ),
      body: hasMatchingEvidence
          ? _copy(
              l10n,
              'Review the highlighted task that matches your Creator receipt.',
              'Revisa la tarea resaltada que coincide con tu recibo de Creador.',
            )
          : _copy(
              l10n,
              'ChronoSpark will not mark this lesson complete until the exact task from your Creator receipt appears here.',
              'ChronoSpark no completará esta lección hasta que aparezca aquí la tarea exacta de tu recibo de Creador.',
            ),
      primaryLabel: _completingTimeline
          ? _copy(l10n, 'Finishing', 'Finalizando')
          : _copy(l10n, 'I found my task', 'Encontré mi tarea'),
      primaryEnabled: hasMatchingEvidence && !_completingTimeline,
      onPrimary: () => unawaited(_completeTimelineLesson()),
      secondaryLabel: _copy(l10n, 'Finish later', 'Terminar más tarde'),
      onSecondary: () => unawaited(
        ref
            .read(adaptiveGuidanceProvider.notifier)
            .later(GuidanceLessonId.reviewTimeline),
      ),
    );
  }

  Future<void> _completeTimelineLesson() async {
    if (_completingTimeline) return;
    final AdaptiveGuidanceState? guidance = ref
        .read(adaptiveGuidanceProvider)
        .asData
        ?.value;
    final String? evidenceTaskId = ref.read(timelineTutorialEvidenceProvider);
    if (guidance == null ||
        guidance.expectedFirstRunCreatorTaskIds.isEmpty ||
        evidenceTaskId == null ||
        !guidance.matchesExpectedFirstRunCreatorTask(evidenceTaskId) ||
        FirstRunTutorialTargets.timelineEvidence.currentContext == null) {
      return;
    }
    setState(() {
      _completingTimeline = true;
      _suppressedLesson = GuidanceLessonId.reviewTimeline;
    });
    try {
      await ref
          .read(adaptiveGuidanceProvider.notifier)
          .record(GuidanceMilestone.firstTimelineReview);
    } finally {
      if (mounted) setState(() => _completingTimeline = false);
    }
  }

  Widget _advancedLesson(
    BuildContext context,
    GuidanceLesson lesson,
    String location,
  ) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final bool alreadyHere = location == lesson.route;
    return InteractiveTutorialOverlay(
      targetKey: _untargetedLessonKey,
      stepLabel: l10n.text(ChronoSparkString.contextualGuidance),
      title: l10n.guideTitle(lesson.id.name, lesson.title),
      body: l10n.guideBody(lesson.id.name, lesson.body),
      primaryLabel: alreadyHere
          ? l10n.text(ChronoSparkString.useThisScreen)
          : l10n.guideAction(lesson.id.name, lesson.actionLabel),
      onPrimary: () {
        if (alreadyHere) {
          setState(() => _suppressedLesson = lesson.id);
        } else {
          context.go(lesson.route);
        }
      },
      secondaryLabel: l10n.text(ChronoSparkString.notNow),
      onSecondary: () => unawaited(
        ref.read(adaptiveGuidanceProvider.notifier).skip(lesson.id),
      ),
      allowTargetInteraction: false,
    );
  }

  _CreatorStepCopy _creatorStepCopy(
    ChronoSparkLocalizations l10n,
    CreatorTutorialStep step,
  ) {
    return switch (step) {
      CreatorTutorialStep.title => _CreatorStepCopy(
        targetKey: FirstRunTutorialTargets.creatorTitle,
        title: _copy(l10n, 'Name the real task', 'Nombra la tarea real'),
        body: _copy(
          l10n,
          'Type a concrete outcome in the highlighted title field. The guide waits for your input.',
          'Escribe un resultado concreto en el campo resaltado. La guía espera tu entrada.',
        ),
        action: _copy(l10n, 'Title entered', 'Título escrito'),
      ),
      CreatorTutorialStep.priority => _CreatorStepCopy(
        targetKey: FirstRunTutorialTargets.creatorPriority,
        title: _copy(l10n, 'Set its priority', 'Define su prioridad'),
        body: _copy(
          l10n,
          'Choose how important this task is. Your selection helps rank upcoming work.',
          'Elige la importancia de esta tarea. Tu selección ayuda a ordenar el trabajo próximo.',
        ),
        action: _copy(l10n, 'Priority chosen', 'Prioridad elegida'),
      ),
      CreatorTutorialStep.schedule => _CreatorStepCopy(
        targetKey: FirstRunTutorialTargets.creatorSchedule,
        title: _copy(l10n, 'Put it on the calendar', 'Ponla en el calendario'),
        body: _copy(
          l10n,
          'Choose a real date and time. Scheduling is required for this first task so it can appear on Timeline.',
          'Elige una fecha y hora reales. La primera tarea necesita horario para aparecer en Línea de Tiempo.',
        ),
        action: _copy(l10n, 'Schedule chosen', 'Horario elegido'),
      ),
      CreatorTutorialStep.save => _CreatorStepCopy(
        targetKey: FirstRunTutorialTargets.creatorSave,
        title: _copy(l10n, 'Review before saving', 'Revisa antes de guardar'),
        body: _copy(
          l10n,
          'Open the confirmation preview and verify the exact task. Nothing is saved until the final confirmation.',
          'Abre la vista de confirmación y verifica la tarea exacta. Nada se guarda hasta la confirmación final.',
        ),
        action: _copy(l10n, 'Review changes', 'Revisar cambios'),
      ),
      CreatorTutorialStep.confirm => _CreatorStepCopy(
        targetKey: FirstRunTutorialTargets.creatorConfirm,
        title: _copy(
          l10n,
          'Confirm the exact task',
          'Confirma la tarea exacta',
        ),
        body: _copy(
          l10n,
          'Confirm the reviewed task once. ChronoSpark will save it and open Timeline so you can verify where it landed.',
          'Confirma la tarea revisada una vez. ChronoSpark la guardará y abrirá Línea de Tiempo para verificar dónde quedó.',
        ),
        action: _completingCreator
            ? _copy(l10n, 'Saving', 'Guardando')
            : _copy(
                l10n,
                'Confirm and open Timeline',
                'Confirmar y abrir Línea de Tiempo',
              ),
      ),
    };
  }

  String _copy(ChronoSparkLocalizations l10n, String english, String spanish) {
    return l10n.isSpanish ? spanish : english;
  }
}

class _CreatorStepCopy {
  const _CreatorStepCopy({
    required this.targetKey,
    required this.title,
    required this.body,
    required this.action,
  });

  final GlobalKey targetKey;
  final String title;
  final String body;
  final String action;
}
