import 'dart:async';

import 'package:fantastic_guacamole/app/router/route_guards.dart'
    show onboardingCompleteGuardProvider;
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/creator_draft_provider.dart';
import 'package:fantastic_guacamole/state/providers/creator_handshake_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/tutorial/first_run_tutorial_state.dart';
import 'package:fantastic_guacamole/tutorial/guide_hint_card.dart';
import 'package:fantastic_guacamole/tutorial/guide_hint_layout.dart';
import 'package:fantastic_guacamole/tutorial/guide_step_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Event-driven guidance shown as a small card at the top of the app that
/// never blocks it. A first-run guide step appears only on the screen it is
/// about and stays until it is done, skipped or paused; a contextual hint
/// appears once on its own screen.
class AdaptiveGuideOverlay extends ConsumerStatefulWidget {
  const AdaptiveGuideOverlay({required this.router, super.key});

  final GoRouter router;

  @override
  ConsumerState<AdaptiveGuideOverlay> createState() =>
      _AdaptiveGuideOverlayState();
}

class _AdaptiveGuideOverlayState extends ConsumerState<AdaptiveGuideOverlay> {
  CreatorTutorialStep _creatorStep = CreatorTutorialStep.title;
  GuidanceLessonId? _suppressedLesson;
  GuidanceLesson? _shownHint;
  (int, String?)? _shownHintOwner;
  bool _completingCreator = false;
  bool _confirmingFoundTask = false;
  bool _keyboardWasOpen = false;
  int _keyboardCloses = 0;
  GuideHintModalObserver? _modals;

  @override
  void initState() {
    super.initState();
    _modals = GuideHintModalObserver.of(widget.router)
      ?..addListener(_onModalsChanged);
  }

  @override
  void didUpdateWidget(covariant AdaptiveGuideOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.router, widget.router)) {
      _modals?.removeListener(_onModalsChanged);
      _modals = GuideHintModalObserver.of(widget.router)
        ?..addListener(_onModalsChanged);
    }
  }

  @override
  void dispose() {
    _modals?.removeListener(_onModalsChanged);
    super.dispose();
  }

  void _onModalsChanged() {
    if (mounted) setState(() {});
  }

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
    // The same per-account answer the router uses. The device-wide flag is
    // not a runtime decision: a content-version bump or a failed preferences
    // read must not silently turn the guide off for a signed-in account.
    final bool onboardingComplete = ref.watch(onboardingCompleteGuardProvider);
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
    ref.listen<AsyncValue<AdaptiveGuidanceState>>(
      adaptiveGuidanceProvider,
      (previous, next) => _openScheduleAfterGuidedSave(
        previous?.asData?.value,
        next.asData?.value,
      ),
    );

    final DailyDecisionIntelligence decision = ref.watch(
      dailyDecisionIntelligenceProvider,
    );
    final GuidanceLesson? lesson = guidance.nextIntervention(
      currentRoute: location,
      decision: decision,
    );

    if (lesson == null || !_isCoreLesson(lesson.id)) {
      final GuidanceLesson? hint = _visibleHint(
        lesson,
        guidance,
        location,
        boundary,
      );
      return hint == null
          ? const SizedBox.shrink()
          : _contextualHint(context, hint);
    }

    // GuideHintSlot closes a card for the rest of a visit once the keyboard
    // opens. A guide step must stay until it is done, so each time the
    // keyboard closes the step gets a new slot and comes back.
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (_keyboardWasOpen && !keyboardOpen) _keyboardCloses++;
    _keyboardWasOpen = keyboardOpen;

    // A step is shown only on the screen it is about; everywhere else the
    // app is left alone (including Settings and the Smart Planner choice
    // offered at the end of setup).
    final Widget? step = switch (lesson.id) {
      GuidanceLessonId.createFirstItem ||
      GuidanceLessonId.scheduleFirstItem => switch (location) {
        RoutePaths.creator => _creatorStepCard(
          context,
          ref.watch(creatorHandshakeProvider),
          lesson,
        ),
        RoutePaths.nexus => _startStepCard(context, lesson),
        _ => null,
      },
      GuidanceLessonId.reviewTimeline =>
        location == RoutePaths.timeline
            ? _timelineStepCard(
                context,
                guidance,
                lesson,
                ref.watch(timelineTutorialEvidenceProvider),
              )
            : null,
      _ => null,
    };
    if (step == null) return const SizedBox.shrink();
    return GuideHintSlot(
      key: ValueKey<Object?>((
        'guide-step',
        lesson.id,
        boundary.generation,
        boundary.userId,
        _keyboardCloses,
      )),
      hidden: _modals?.hasModalOnTop ?? false,
      child: step,
    );
  }

  /// The contextual hint for this visit to [location]. A hint is stored as
  /// seen once it has actually been drawn (see [GuideHintSlot]), so it is
  /// shown once per account; it then stays until the person dismisses it,
  /// acts on it, does the page's real action, or leaves the page.
  GuidanceLesson? _visibleHint(
    GuidanceLesson? lesson,
    AdaptiveGuidanceState guidance,
    String location,
    AuthSessionBoundary boundary,
  ) {
    final (int, String?) owner = (boundary.generation, boundary.userId);
    if (lesson != null &&
        lesson.route == location &&
        (_shownHint?.id != lesson.id || _shownHintOwner != owner)) {
      _shownHint = lesson;
      _shownHintOwner = owner;
    }
    final GuidanceLesson? shown = _shownHint;
    if (shown == null ||
        shown.route != location ||
        _shownHintOwner != owner ||
        _suppressedLesson == shown.id ||
        guidance.skippedLessons.contains(shown.id) ||
        guidance.lessonFinishedByAction(shown.id)) {
      return null;
    }
    return lesson?.id == shown.id ? lesson : shown;
  }

  /// Called by [GuideHintSlot] after the card was drawn on screen.
  void _rememberHintShown(GuidanceLessonId id, (int, String?)? owner) {
    if (!mounted) return;
    final AuthSessionBoundary current = ref.read(authSessionBoundaryProvider);
    if ((current.generation, current.userId) != owner ||
        current.isTransitioning ||
        !current.isStorageReady) {
      return;
    }
    unawaited(
      ref.read(adaptiveGuidanceProvider.notifier).completeLesson(id).catchError(
        (Object error) {
          // Not stored: the hint may show once more on a later visit.
          Logger.warn('Contextual hint could not be stored as seen.');
        },
      ),
    );
  }

  bool _isCoreLesson(GuidanceLessonId id) =>
      AdaptiveGuidanceState.coreStepNumber(id) != null;

  String _pauseLabel(ChronoSparkLocalizations l10n) =>
      _copy(l10n, 'Pause guide', 'Pausar guía');

  String _skipStepLabel(ChronoSparkLocalizations l10n) =>
      _copy(l10n, 'Skip this step', 'Omitir este paso');

  /// "Step 1 of 2", counted as the person sees the guide.
  String _stepLabel(ChronoSparkLocalizations l10n, GuidanceLessonId id) {
    final int number = AdaptiveGuidanceState.coreStepNumber(id)!;
    const int total = AdaptiveGuidanceState.coreStepCount;
    return _copy(l10n, 'Step $number of $total', 'Paso $number de $total');
  }

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

  /// "Skip this step": the guide moves on without recording anything as
  /// done. When it was the last step, say how to bring the guide back.
  Future<void> _skipStep(BuildContext context, GuidanceLessonId lesson) async {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _creatorStep = CreatorTutorialStep.title);
    await ref.read(adaptiveGuidanceProvider.notifier).skipCoreStep(lesson);
    if (!mounted ||
        ref.read(adaptiveGuidanceProvider).asData?.value.activeCoreLesson !=
            null) {
      return;
    }
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('guide-skipped-snackbar'),
          content: Text(
            _copy(
              l10n,
              'Guide skipped. Restart it anytime in Settings › Restart Adaptive Guide.',
              'Guía omitida. Reiníciala cuando quieras en Ajustes › Reiniciar la Guía Adaptativa.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Step 1 on Today: where adding the first task starts.
  Widget _startStepCard(BuildContext context, GuidanceLesson lesson) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    return GuideStepCard(
      key: const Key('guide_step_card'),
      progressLabel: _stepLabel(l10n, lesson.id),
      title: l10n.guideTitle(lesson.id.name, lesson.title),
      body: l10n.guideBody(lesson.id.name, lesson.body),
      primaryLabel: l10n.guideAction(lesson.id.name, lesson.actionLabel),
      onPrimary: () => widget.router.go(lesson.route),
      skipStepLabel: _skipStepLabel(l10n),
      onSkipStep: () => unawaited(_skipStep(context, lesson.id)),
      pauseLabel: _pauseLabel(l10n),
      onPause: () => _pauseGuide(context, lesson.id),
    );
  }

  Widget _creatorStepCard(
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
    final bool canGoBack =
        activeStep != CreatorTutorialStep.title && !_completingCreator;

    return GuideStepCard(
      key: const Key('guide_step_card'),
      progressLabel: _stepLabel(l10n, lesson.id),
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
      skipStepLabel: _skipStepLabel(l10n),
      onSkipStep: () => unawaited(_skipStep(context, lesson.id)),
      pauseLabel: _pauseLabel(l10n),
      onPause: () => _pauseGuide(context, lesson.id),
      backLabel: canGoBack ? _copy(l10n, 'Back', 'Atrás') : null,
      onBack: canGoBack ? () => _creatorBack(activeStep) : null,
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

  void _resetCreatorGuide() {
    ref.read(creatorTutorialDraftProvider.notifier).reset();
    ref.read(creatorDraftPreviewProvider.notifier).clear();
    setState(() => _creatorStep = CreatorTutorialStep.title);
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
      // tapping the Creator's own confirm button behaves the same as this one.
      final CreatorHandshakeState result = await ref
          .read(creatorHandshakeProvider.notifier)
          .confirm();
      if (result.receipt == null || !mounted) return;
      _resetCreatorGuide();
      if (hasSchedule && context.mounted) {
        widget.router.go(RoutePaths.timeline);
      }
    } finally {
      if (mounted) setState(() => _completingCreator = false);
    }
  }

  /// The guided task was saved with a date through the Creator's own confirm
  /// button: open the schedule, where the next step is, as the card's own
  /// confirm action does.
  void _openScheduleAfterGuidedSave(
    AdaptiveGuidanceState? previous,
    AdaptiveGuidanceState? next,
  ) {
    if (previous == null || next == null || _completingCreator) return;
    if (AdaptiveGuidanceState.coreStepNumber(
              previous.activeCoreLesson ?? GuidanceLessonId.nexus,
            ) !=
            1 ||
        next.activeCoreLesson != GuidanceLessonId.reviewTimeline ||
        next.count(GuidanceMilestone.firstSchedule) <=
            previous.count(GuidanceMilestone.firstSchedule)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.router.routerDelegate.currentConfiguration.isEmpty ||
          widget.router.routerDelegate.state.uri.path != RoutePaths.creator) {
        return;
      }
      _resetCreatorGuide();
      widget.router.go(RoutePaths.timeline);
    });
  }

  /// Step 2 on the schedule. It ends when the person says they found the
  /// task; marking it done is not required.
  Widget _timelineStepCard(
    BuildContext context,
    AdaptiveGuidanceState guidance,
    GuidanceLesson lesson,
    String? timelineEvidenceTaskId,
  ) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    bool allExpectedTasksUnavailable =
        guidance.expectedFirstRunCreatorTaskIds.isNotEmpty;
    for (final String id in guidance.expectedFirstRunCreatorTaskIds) {
      final AsyncValue<TaskEntity?> taskState = ref.watch(
        firstRunTutorialTaskProvider(id),
      );
      final TaskEntity? task = taskState.asData?.value;
      if (taskState.asData == null ||
          (task?.isActionableAt(DateTime.now()) ?? false)) {
        allExpectedTasksUnavailable = false;
      }
    }
    final bool hasMatchingEvidence =
        timelineEvidenceTaskId != null &&
        guidance.matchesExpectedFirstRunCreatorTask(timelineEvidenceTaskId) &&
        FirstRunTutorialTargets.timelineEvidence.currentContext != null;
    return GuideStepCard(
      key: const Key('guide_step_card'),
      progressLabel: _stepLabel(l10n, lesson.id),
      title: hasMatchingEvidence
          ? _copy(
              l10n,
              'Your saved task is now on Schedule',
              'Tu tarea guardada ya está en agenda',
            )
          : l10n.guideTitle(lesson.id.name, lesson.title),
      body: hasMatchingEvidence
          ? _copy(
              l10n,
              'This is the task you just saved, at its scheduled time. Check its date and details, then tap I found my task.',
              'Esta es la tarea que acabas de guardar, en su hora programada. Revisa su fecha y sus detalles y toca Encontré mi tarea.',
            )
          : allExpectedTasksUnavailable
          ? _copy(
              l10n,
              'This task is no longer on your schedule. Tap Skip this step to finish the guide.',
              'Esta tarea ya no está en tu agenda. Toca Omitir este paso para terminar la guía.',
            )
          : _copy(
              l10n,
              'Your new task appears here as soon as Schedule loads it.',
              'Tu nueva tarea aparecerá aquí en cuanto la agenda la cargue.',
            ),
      primaryLabel: _copy(l10n, 'I found my task', 'Encontré mi tarea'),
      primaryEnabled: !_confirmingFoundTask,
      onPrimary: () => unawaited(_confirmFoundTask(context)),
      skipStepLabel: _skipStepLabel(l10n),
      onSkipStep: () => unawaited(_skipStep(context, lesson.id)),
      pauseLabel: _pauseLabel(l10n),
      onPause: () => _pauseGuide(context, lesson.id),
    );
  }

  /// "I found my task" records the schedule review and so finishes the
  /// first-run guide.
  Future<void> _confirmFoundTask(BuildContext context) async {
    if (_confirmingFoundTask) return;
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    final AuthSessionBoundary boundary = ref.read(authSessionBoundaryProvider);
    bool isCurrent() {
      if (!mounted) return false;
      final AuthSessionBoundary now = ref.read(authSessionBoundaryProvider);
      return now.generation == boundary.generation &&
          now.userId == boundary.userId &&
          now.isStorageReady &&
          !now.isTransitioning &&
          now.blockingIssue == null &&
          ref.read(adaptiveGuidanceProvider).asData?.value.activeCoreLesson ==
              GuidanceLessonId.reviewTimeline;
    }

    if (!isCurrent()) return;
    setState(() => _confirmingFoundTask = true);
    try {
      await ref
          .read(adaptiveGuidanceProvider.notifier)
          .record(
            GuidanceMilestone.firstTimelineReview,
            shouldContinue: isCurrent,
          );
    } catch (_) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _copy(
                l10n,
                'Could not finish the guide. Try again.',
                'No se pudo finalizar la guía. Inténtalo de nuevo.',
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _confirmingFoundTask = false);
    }
  }

  /// A small card at the top of the app that leaves the page usable.
  Widget _contextualHint(BuildContext context, GuidanceLesson lesson) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final (int, String?)? owner = _shownHintOwner;
    return GuideHintSlot(
      // A new hint or account starts a new slot, with its own seen state.
      key: ValueKey<Object?>((lesson.id, owner)),
      hidden: _modals?.hasModalOnTop ?? false,
      onShown: () => _rememberHintShown(lesson.id, owner),
      child: GuideHintCard(
        key: const Key('guide_hint_card'),
        label: l10n.text(ChronoSparkString.contextualGuidance),
        title: l10n.guideTitle(lesson.id.name, lesson.title),
        body: l10n.guideBody(lesson.id.name, lesson.body),
        // "Not now" keeps its stored per-lesson mute, which Settings counts.
        dismissLabel: l10n.text(ChronoSparkString.notNow),
        onDismiss: () {
          setState(() => _suppressedLesson = lesson.id);
          unawaited(
            ref.read(adaptiveGuidanceProvider.notifier).skip(lesson.id),
          );
        },
        actionLabel: _copy(l10n, 'Got it', 'Entendido'),
        onAction: () {
          // Hidden now without waiting for storage; remembered as finished.
          setState(() => _suppressedLesson = lesson.id);
          unawaited(
            ref
                .read(adaptiveGuidanceProvider.notifier)
                .completeLesson(lesson.id),
          );
        },
      ),
    );
  }

  _CreatorStepCopy _creatorStepCopy(
    ChronoSparkLocalizations l10n,
    CreatorTutorialStep step,
  ) {
    return switch (step) {
      CreatorTutorialStep.title => _CreatorStepCopy(
        title: _copy(l10n, 'Name the real task', 'Nombra la tarea real'),
        body: _copy(
          l10n,
          'Type a concrete outcome in the title field below, then tap Title entered.',
          'Escribe un resultado concreto en el campo de título de abajo y toca Título escrito.',
        ),
        action: _copy(l10n, 'Title entered', 'Título escrito'),
      ),
      CreatorTutorialStep.priority => _CreatorStepCopy(
        title: _copy(l10n, 'Set its priority', 'Define su prioridad'),
        body: _copy(
          l10n,
          'Choose how important this task is. Your selection helps rank upcoming work.',
          'Elige la importancia de esta tarea. Tu selección ayuda a ordenar el trabajo próximo.',
        ),
        action: _copy(l10n, 'Priority chosen', 'Prioridad elegida'),
      ),
      CreatorTutorialStep.schedule => _CreatorStepCopy(
        title: _copy(l10n, 'Put it on the calendar', 'Ponla en el calendario'),
        body: _copy(
          l10n,
          'Choose a real date and time. Scheduling is required for this first task so it can appear on Schedule.',
          'Elige una fecha y hora reales. La primera tarea necesita horario para aparecer en agenda.',
        ),
        action: _copy(l10n, 'Schedule chosen', 'Horario elegido'),
      ),
      CreatorTutorialStep.save => _CreatorStepCopy(
        title: _copy(l10n, 'Review before saving', 'Revisa antes de guardar'),
        body: _copy(
          l10n,
          'Open the confirmation preview and verify the exact task. Nothing is saved until the final confirmation.',
          'Abre la vista de confirmación y verifica la tarea exacta. Nada se guarda hasta la confirmación final.',
        ),
        action: _copy(l10n, 'Review changes', 'Revisar cambios'),
      ),
      CreatorTutorialStep.confirm => _CreatorStepCopy(
        title: _copy(
          l10n,
          'Confirm the exact task',
          'Confirma la tarea exacta',
        ),
        body: _copy(
          l10n,
          'Confirm the reviewed task once. Axiomara will save it and open Schedule so you can verify where it landed.',
          'Confirma la tarea revisada una vez. Axiomara la guardará y abrirá agenda para verificar dónde quedó.',
        ),
        action: _completingCreator
            ? _copy(l10n, 'Saving', 'Guardando')
            : _copy(
                l10n,
                'Confirm and open Schedule',
                'Confirmar y abrir agenda',
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
    required this.title,
    required this.body,
    required this.action,
  });

  final String title;
  final String body;
  final String action;
}
