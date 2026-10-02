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
  const AdaptiveGuideOverlay({required this.router, super.key});

  final GoRouter router;

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
  String? _acknowledgedTimelineTaskId;
  bool _completingTimeline = false;
  bool _timelineCompletionFailed = false;

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
    final auth = ref.watch(authUserProvider).asData?.value;
    final AuthSessionBoundary boundary = ref.watch(authSessionBoundaryProvider);
    final String location =
        widget.router.routerDelegate.currentConfiguration.isEmpty
        ? ''
        : widget.router.routerDelegate.state.uri.path;

    // Account-scoped intelligence fails closed until authentication and its
    // storage boundary agree. Do not subscribe to those providers from the
    // signed-out/login frame or while an account transition is still settling.
    if (!onboardingComplete ||
        interactionPaused ||
        auth == null ||
        boundary.isTransitioning ||
        !boundary.isStorageReady ||
        boundary.blockingIssue != null ||
        boundary.userId != auth.id ||
        !_routeAllowsGuidance(location)) {
      return const SizedBox.shrink();
    }

    final AdaptiveGuidanceState? guidance = ref
        .watch(adaptiveGuidanceProvider)
        .asData
        ?.value;
    if (guidance == null) {
      return const SizedBox.shrink();
    }

    final DailyDecisionIntelligence decision = ref.watch(
      dailyDecisionIntelligenceProvider,
    );
    final GuidanceLesson? lesson = guidance.nextIntervention(
      currentRoute: location,
      decision: decision,
    );

    if (lesson == null || _suppressedLesson == lesson.id) {
      return const SizedBox.shrink();
    }

    // Onboarding's "Show one helpful choice" opens Smart Planner. A full-screen
    // first-run prompt there would hide the choice the person just asked for;
    // core guidance resumes on the next screen they open.
    if (_isCoreLesson(lesson.id) && location == RoutePaths.smartPlanner) {
      return const SizedBox.shrink();
    }

    if (lesson.id == GuidanceLessonId.createFirstItem ||
        lesson.id == GuidanceLessonId.scheduleFirstItem) {
      if (location != RoutePaths.creator) {
        return _routePrompt(context, lesson);
      }
      final CreatorHandshakeState handshake = ref.watch(
        creatorHandshakeProvider,
      );
      return _creatorLesson(context, handshake, lesson);
    }

    if (lesson.id == GuidanceLessonId.reviewTimeline) {
      if (location != RoutePaths.timeline) {
        return _routePrompt(context, lesson);
      }
      final String? timelineEvidenceTaskId = ref.watch(
        timelineTutorialEvidenceProvider,
      );
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
      onPrimary: () => widget.router.go(lesson.route),
      secondaryLabel: _pauseLabel(l10n),
      onSecondary: () => _pauseGuide(context, lesson.id),
      allowTargetInteraction: false,
    );
  }

  bool _isCoreLesson(GuidanceLessonId id) =>
      id == GuidanceLessonId.createFirstItem ||
      id == GuidanceLessonId.scheduleFirstItem ||
      id == GuidanceLessonId.reviewTimeline;

  String _pauseLabel(ChronoSparkLocalizations l10n) =>
      _copy(l10n, 'Pause guide', 'Pausar guía');

  /// Pausing persists until the person finishes the step on their own or
  /// restarts the guide, so say where to resume instead of implying "later".
  void _pauseGuide(BuildContext context, GuidanceLessonId lesson) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    unawaited(ref.read(adaptiveGuidanceProvider.notifier).later(lesson));
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('guide-paused-snackbar'),
          content: Text(
            _copy(
              l10n,
              'Guide paused. Resume it anytime in Settings › Restart Adaptive Guide.',
              'Guía en pausa. Reanúdala cuando quieras en Ajustes › Reiniciar la Guía Adaptativa.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
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
      secondaryLabel: _pauseLabel(l10n),
      onSecondary: () => _pauseGuide(context, lesson.id),
      backLabel: _copy(l10n, 'Back', 'Atrás'),
      onBack: activeStep == CreatorTutorialStep.title || _completingCreator
          ? null
          : () => _creatorBack(activeStep),
    );
  }

  void _creatorBack(CreatorTutorialStep activeStep) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (activeStep == CreatorTutorialStep.confirm) {
      // Leaving review keeps the form (same revision) so the draft can be
      // edited, matching the review card's own "Edit draft" action.
      ref.read(creatorHandshakeProvider.notifier).cancelPreview();
      setState(() => _creatorStep = CreatorTutorialStep.save);
      return;
    }
    setState(() {
      _creatorStep = CreatorTutorialStep.values[activeStep.index - 1];
    });
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
      // confirm() records the Creator receipt for Timeline review itself, so
      // tapping the highlighted Creator button behaves the same as this one.
      final CreatorHandshakeState result = await ref
          .read(creatorHandshakeProvider.notifier)
          .confirm();
      if (result.receipt == null || !mounted) return;
      ref.read(creatorTutorialDraftProvider.notifier).reset();
      ref.read(creatorDraftPreviewProvider.notifier).clear();
      setState(() => _creatorStep = CreatorTutorialStep.title);
      if (hasSchedule && context.mounted) {
        widget.router.go(RoutePaths.timeline);
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
    String? completedTaskId;
    bool allExpectedTasksUnavailable = hasExpectedReceipt;
    for (final id in guidance.expectedFirstRunCreatorTaskIds) {
      final taskState = ref.watch(firstRunTutorialTaskProvider(id));
      final task = taskState.asData?.value;
      if (task?.isCompleted ?? false) completedTaskId ??= id;
      if (taskState.asData == null ||
          (task?.isActionableAt(DateTime.now()) ?? false)) {
        allExpectedTasksUnavailable = false;
      }
    }
    if (completedTaskId != null) {
      final String id = completedTaskId;
      return InteractiveTutorialOverlay(
        targetKey: _untargetedLessonKey,
        title: _copy(l10n, 'Your task is complete', 'Tu tarea está completada'),
        body: _timelineCompletionFailed
            ? _copy(
                l10n,
                'Could not finish the guide. Try again.',
                'No se pudo finalizar la guía. Inténtalo de nuevo.',
              )
            : _copy(
                l10n,
                'Your saved task is already complete. Finish the guide to return to Axiomara.',
                'Tu tarea guardada ya está completada. Finaliza la guía para volver a Axiomara.',
              ),
        primaryLabel: _copy(l10n, 'Finish guide', 'Finalizar guía'),
        primaryEnabled: !_completingTimeline,
        onPrimary: () => unawaited(_finishCompletedTimelineTask(id)),
        secondaryLabel: _pauseLabel(l10n),
        onSecondary: () =>
            _pauseGuide(context, GuidanceLessonId.reviewTimeline),
        allowTargetInteraction: false,
      );
    }
    final bool hasMatchingEvidence =
        hasExpectedReceipt &&
        timelineEvidenceTaskId != null &&
        guidance.matchesExpectedFirstRunCreatorTask(timelineEvidenceTaskId) &&
        FirstRunTutorialTargets.timelineEvidence.currentContext != null;
    final bool completionTargetAvailable =
        FirstRunTutorialTargets.timelineCompletion.currentContext != null;
    final bool showingCompletionStep =
        hasMatchingEvidence &&
        _acknowledgedTimelineTaskId == timelineEvidenceTaskId &&
        completionTargetAvailable;
    return InteractiveTutorialOverlay(
      targetKey: showingCompletionStep
          ? FirstRunTutorialTargets.timelineCompletion
          : FirstRunTutorialTargets.timelineEvidence,
      stepLabel: _copy(
        l10n,
        showingCompletionStep
            ? 'Guided setup · complete your task'
            : 'Guided setup · find your task',
        showingCompletionStep
            ? 'Configuración guiada · completa tu tarea'
            : 'Configuración guiada · encuentra tu tarea',
      ),
      title: showingCompletionStep
          ? _copy(l10n, 'Complete your task', 'Completa tu tarea')
          : hasMatchingEvidence
          ? _copy(
              l10n,
              'Your saved task is now on Timeline',
              'Tu tarea guardada ya está en Línea de Tiempo',
            )
          : _copy(l10n, 'Finding your task', 'Buscando tu tarea'),
      body: allExpectedTasksUnavailable
          ? _copy(
              l10n,
              'This task is no longer available to complete here. Pause the guide to review your tasks, or restart the guide from Settings.',
              'Esta tarea ya no está disponible para completarla aquí. Pausa la guía para revisar tus tareas o reiníciala desde Ajustes.',
            )
          : showingCompletionStep
          ? _copy(
              l10n,
              'Tap Complete on the highlighted task. This saves the first outcome Axiomara can learn from.',
              'Toca Completar en la tarea resaltada. Así guardas el primer resultado del que Axiomara puede aprender.',
            )
          : hasMatchingEvidence
          ? _copy(
              l10n,
              'This is the task you just saved, placed at its scheduled time. When it is due, complete it here.',
              'Esta es la tarea que acabas de guardar, en su hora programada. Cuando llegue el momento, complétala aquí.',
            )
          : _copy(
              l10n,
              'Your new task will be highlighted here as soon as Timeline loads it.',
              'Tu nueva tarea se resaltará aquí en cuanto la Línea de Tiempo la cargue.',
            ),
      primaryLabel: showingCompletionStep
          ? _copy(
              l10n,
              'Complete the highlighted task',
              'Completar la tarea resaltada',
            )
          : _copy(l10n, 'I found my task', 'Encontré mi tarea'),
      primaryEnabled:
          !showingCompletionStep &&
          hasMatchingEvidence &&
          !allExpectedTasksUnavailable,
      onPrimary: () => unawaited(_acknowledgeTimelineTask()),
      secondaryLabel: _pauseLabel(l10n),
      onSecondary: () => _pauseGuide(context, GuidanceLessonId.reviewTimeline),
    );
  }

  Future<void> _acknowledgeTimelineTask() async {
    final AdaptiveGuidanceState? guidance = ref
        .read(adaptiveGuidanceProvider)
        .asData
        ?.value;
    final String? evidenceTaskId = ref.read(timelineTutorialEvidenceProvider);
    if (guidance == null ||
        evidenceTaskId == null ||
        !guidance.matchesExpectedFirstRunCreatorTask(evidenceTaskId) ||
        FirstRunTutorialTargets.timelineEvidence.currentContext == null) {
      return;
    }
    setState(() => _acknowledgedTimelineTaskId = evidenceTaskId);
  }

  Future<void> _finishCompletedTimelineTask(String taskId) async {
    if (_completingTimeline) return;
    final boundary = ref.read(authSessionBoundaryProvider);
    bool isCurrent() =>
        mounted &&
        ref.read(authSessionBoundaryProvider).generation ==
            boundary.generation &&
        ref.read(authSessionBoundaryProvider).userId == boundary.userId &&
        ref.read(authSessionBoundaryProvider).isStorageReady &&
        !ref.read(authSessionBoundaryProvider).isTransitioning &&
        ref.read(authSessionBoundaryProvider).blockingIssue == null &&
        ref.read(adaptiveGuidanceProvider).asData?.value.activeCoreLesson ==
            GuidanceLessonId.reviewTimeline &&
        (ref
                .read(adaptiveGuidanceProvider)
                .asData
                ?.value
                .matchesExpectedFirstRunCreatorTask(taskId) ??
            false);
    setState(() {
      _completingTimeline = true;
      _timelineCompletionFailed = false;
    });
    try {
      final task = await ref
          .read(domainTaskRepositoryProvider)
          .getTaskById(taskId);
      if (!isCurrent()) return;
      if (task?.isCompleted != true) {
        ref.invalidate(firstRunTutorialTaskProvider(taskId));
        return;
      }
      await ref
          .read(adaptiveGuidanceProvider.notifier)
          .record(
            GuidanceMilestone.firstTimelineReview,
            shouldContinue: isCurrent,
          );
    } catch (_) {
      if (mounted) setState(() => _timelineCompletionFailed = true);
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
          widget.router.go(lesson.route);
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
          'Confirm the reviewed task once. Axiomara will save it and open Timeline so you can verify where it landed.',
          'Confirma la tarea revisada una vez. Axiomara la guardará y abrirá Línea de Tiempo para verificar dónde quedó.',
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
