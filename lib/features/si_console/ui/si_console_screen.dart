import 'dart:async';
import 'dart:math' as math;

import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/errors/public_failure.dart';
import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/value_objects/ai_content_report_reason.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_console_query_controller.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/providers/ai_content_report_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/milestones_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/crisis_dialog.dart';
import 'package:fantastic_guacamole/ui/widgets/error_view.dart';
import 'package:fantastic_guacamole/ui/widgets/loading_overlay.dart';
import 'package:fantastic_guacamole/ui/widgets/typing_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class _Msg {
  const _Msg({
    required this.text,
    required this.isUser,
    this.emotion,
    this.rationale,
    this.confidence,
  });
  final String text;
  final bool isUser;
  final String? emotion;
  final String? rationale;
  final double? confidence;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SIConsoleScreen extends ConsumerStatefulWidget {
  const SIConsoleScreen({super.key});

  @override
  ConsumerState<SIConsoleScreen> createState() => _SIConsoleScreenState();
}

class _SIConsoleScreenState extends ConsumerState<SIConsoleScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final List<_Msg> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _composerKey = GlobalKey();
  // Starting guess only, replaced by the composer's real measured height
  // right after the first frame — see _measureComposer.
  final ValueNotifier<double> _composerHeight = ValueNotifier<double>(220);
  bool _typing = false;
  late final AnimationController _typingAnim;
  StreamSubscription<GoalLifecycleEvent>? _goalEventSubscription;

  /// Captured in [initState] because `ref` cannot be read from [dispose] —
  /// the element is already deactivated by then and Riverpod throws.
  late final Future<void> Function() _stopVoice;
  late final Future<void> Function({
    required String surface,
    required List<String> controls,
  })
  _speakAccessibilityHint;

  void _runAfterBuild(VoidCallback action) {
    if (!mounted) return;
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      action();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      action();
    });
  }

  void _safeSetState(VoidCallback fn) {
    _runAfterBuild(() => setState(fn));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppAnalytics.track('si_opened');
    final voiceService = ref.read(voiceServiceProvider);
    _stopVoice = voiceService.stop;
    _speakAccessibilityHint = voiceService.speakAccessibilityHint;
    _goalEventSubscription = ref
        .read(eventBusProvider)
        .on<GoalLifecycleEvent>()
        .listen((event) {
          if (!mounted) {
            return;
          }
          _safeSetState(() {
            _messages.add(
              _Msg(
                text: 'GOAL SYNC: ${event.action.toUpperCase()} ${event.title}',
                isUser: false,
                emotion: 'engaged',
              ),
            );
          });
          _scrollToBottom();
        });
    _typingAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // Greeting after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addSI(
        'Strategic Intelligence is ready. I will use only the sources currently available, such as tasks, goals, Timeline, Progression, and saved preferences. '
        'Responses may be limited when a source is missing, stale, or offline. Type "help" to see available shortcuts.',
        emotion: 'confident',
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingAnim.dispose();
    _input.dispose();
    _scroll.dispose();
    _composerHeight.dispose();
    unawaited(_stopVoice());
    unawaited(_goalEventSubscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // The keyboard opening/closing resizes the viewport without the SI
    // Console ever leaving resizeToAvoidBottomInset: false, so nothing else
    // re-anchors the transcript to the latest message when that happens.
    // Re-measure first: the keyboard toggle also flips the composer between
    // its compact/expanded layouts, and scrolling before that resize lands
    // would jump to a since-stale maxScrollExtent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureComposer();
      _scrollToBottom();
    });
  }

  void _measureComposer() {
    final double? height = _composerKey.currentContext?.size?.height;
    if (height != null && height != _composerHeight.value) {
      _composerHeight.value = height;
    }
  }

  void _addSI(String text, {String emotion = 'balanced'}) {
    _safeSetState(
      () => _messages.add(_Msg(text: text, isUser: false, emotion: emotion)),
    );
    _scrollToBottom();
  }

  Future<void> _showReportDialog(_Msg msg) async {
    AiContentReportReason selected = AiContentReportReason.unsafe;
    final AiContentReportReason?
    reason = await showDialog<AiContentReportReason>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Report AI response'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Only the selected response and your reason are sent for safety review. Your prompt and conversation history are not included.',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AiContentReportReason>(
                      initialValue: selected,
                      decoration: const InputDecoration(labelText: 'Reason'),
                      items:
                          <AiContentReportReason>[
                                AiContentReportReason.unsafe,
                                AiContentReportReason.inaccurate,
                                AiContentReportReason.privacy,
                                AiContentReportReason.other,
                              ]
                              .map(
                                (AiContentReportReason option) =>
                                    DropdownMenuItem<AiContentReportReason>(
                                      value: option,
                                      child: Text(switch (option) {
                                        AiContentReportReason.unsafe =>
                                          'Unsafe or harmful',
                                        AiContentReportReason.inaccurate =>
                                          'Misleading or inaccurate',
                                        AiContentReportReason.privacy =>
                                          'Privacy concern',
                                        AiContentReportReason.other => 'Other',
                                      }),
                                    ),
                              )
                              .toList(growable: false),
                      onChanged: (AiContentReportReason? value) {
                        if (value != null) setState(() => selected = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(selected),
                  child: const Text('Send report'),
                ),
              ],
            );
          },
        );
      },
    );
    if (reason == null || !mounted) return;
    try {
      await ref
          .read(aiContentReportActionsProvider)
          .submit(responseText: msg.text, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Thanks. The response was reported for safety review.',
            ),
          ),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The response could not be reported. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showAccessibilityGuide() async {
    if (!mounted) {
      return;
    }
    const List<String> controls = <String>[
      'Type a prompt in the input field, then tap send.',
      'Use Summary to hear recent assistant responses.',
      'Use Speak on assistant bubbles to read aloud.',
      'Use Back to return to Smart Planner.',
    ];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0D1420),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return const SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Accessibility Guide',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'A11Y means accessibility. These controls help with readable and spoken guidance.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '1. Type prompt then send',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '2. Summary for quick recap',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '3. Speak reads responses aloud',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '4. Back returns to Smart Planner',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
    unawaited(
      _speakAccessibilityHint(surface: 'SI Console', controls: controls),
    );
  }

  void _send() {
    final String text = _input.text.trim();
    if (text.isEmpty) return;

    if (ref.read(siConsoleQueryControllerProvider).detectsCrisis(text)) {
      showCrisisDialog(context);
      return;
    }

    unawaited(
      ref
          .read(adaptiveGuidanceProvider.notifier)
          .record(GuidanceMilestone.firstSiQuery),
    );

    if (_handleLocalShortcut(text)) {
      _input.clear();
      return;
    }
    _input.clear();

    _safeSetState(() => _messages.add(_Msg(text: text, isUser: true)));
    _scrollToBottom();
    _safeSetState(() => _typing = true);

    _dispatchQuery(text);
  }

  bool _handleLocalShortcut(String text) {
    final String normalized = text.trim().toLowerCase();
    final String shortcut = normalized.split(RegExp(r'\s+')).first;
    final SIConsoleScreenModel? consoleModel = ref
        .read(siConsoleScreenModelProvider)
        .asData
        ?.value;
    final SIStateAggregation? aggregation = consoleModel?.aggregation;

    if (normalized == '/help' || normalized == 'help') {
      _safeSetState(() {
        _messages.add(_Msg(text: text, isUser: true));
        _messages.add(
          const _Msg(
            text:
                'SI QUERY SHORTCUTS\n\n'
                'Quick shortcuts:\n'
                '- /tasks: inspect active tasks and next actions\n'
                '- /goals: summarize goals and drift\n'
                '- /milestones: summarize checkpoint health, risk, and next target\n'
                '- /plan: summarize schedule and next blocks\n'
                '- /timeline: summarize recent milestones/events\n'
                '- /trajectory: summarize momentum, pressure, and prediction\n\n'
                'Rules:\n'
                '- Task creation is Creator-only. Use Creator to create tasks/goals.\n'
                '- SI Console is analysis + guidance, not data-entry.\n\n'
                'High-signal prompts SI responds well to:\n'
                '- "List my 3 newest tasks and what to do first."\n'
                '- "Did I create a task just now? Show the latest task title."\n'
                '- "Summarize trajectory pressure and one corrective action."\n'
                '- "Show plan risks for today and 3 next actions."\n'
                '- "Summarize goals at risk and what to do next."\n'
                '- "Compare current self to future self."\n\n'
                'Tip: use a shortcut first, then add intent. Example: /tasks what should I execute now?',
            isUser: false,
            emotion: 'engaged',
          ),
        );
      });
      _scrollToBottom();
      return true;
    }

    if (normalized == '/status' || normalized == 'status') {
      final String status = (aggregation == null)
          ? 'SI STATUS\n\n'
                'Model is still initializing. Retry /status in a second.\n'
                'If this persists, use /tasks or /plan to warm providers.'
          : 'SI STATUS\n\n'
                'Connected surfaces:\n'
                '- tasks: ${aggregation.tasks.length}\n'
                '- goals: ${aggregation.goals.length}\n'
                '- logs: ${aggregation.logs.length}\n'
                '- memories: ${aggregation.memories.length}\n'
                '- notifications: ${aggregation.notifications.length}\n'
                '- timeline: ${aggregation.timeline.length}\n'
                '- milestones: ${ref.read(milestonesProvider).asData?.value.length ?? 0}\n'
                '- plan preview blocks: ${aggregation.planPreview.length}\n\n'
                'Trajectory:\n'
                '- pressure: ${aggregation.trajectory.pressureIndex}\n'
                '- momentum: ${(aggregation.trajectory.momentum * 100).round()}%\n'
                '- divergence: ${aggregation.trajectory.behaviorDivergence}%\n\n'
                'Use /tasks, /goals, /milestones, /plan, /timeline, and /trajectory for module-specific responses.';

      _safeSetState(() {
        _messages.add(_Msg(text: text, isUser: true));
        _messages.add(_Msg(text: status, isUser: false, emotion: 'engaged'));
      });
      _scrollToBottom();
      return true;
    }

    if (shortcut == '/tasks' ||
        shortcut == '/goals' ||
        shortcut == '/milestones' ||
        shortcut == '/plan' ||
        shortcut == '/timeline' ||
        shortcut == '/trajectory') {
      final String response = _localSurfaceSummary(shortcut, aggregation);
      _safeSetState(() {
        _messages.add(_Msg(text: text, isUser: true));
        _messages.add(_Msg(text: response, isUser: false, emotion: 'engaged'));
      });
      _scrollToBottom();
      return true;
    }

    return false;
  }

  String _localSurfaceSummary(
    String shortcut,
    SIStateAggregation? aggregation,
  ) {
    if (aggregation == null) {
      return 'SI is still loading module data. Retry the shortcut in a second.';
    }

    switch (shortcut) {
      case '/tasks':
        final List<String> top = aggregation.tasks
            .take(3)
            .map((t) => t.title)
            .toList(growable: false);
        final String topText = top.isEmpty
            ? 'No active tasks yet.'
            : top.map((t) => '- $t').join('\n');
        return 'TASKS SNAPSHOT\n\nActive tasks: ${aggregation.tasks.length}\n\nTop tasks:\n$topText\n\nPrompt: "which one should I execute first and why?"';
      case '/goals':
        final List<String> top = aggregation.goals
            .take(3)
            .map((g) => g.title)
            .toList(growable: false);
        final String topText = top.isEmpty
            ? 'No goals found.'
            : top.map((g) => '- $g').join('\n');
        return 'GOALS SNAPSHOT\n\nGoals: ${aggregation.goals.length}\n\nTop goals:\n$topText\n\nPrompt: "which goal is drifting and what is the next corrective action?"';
      case '/plan':
        final String blocks = aggregation.planPreview.isEmpty
            ? 'No adaptive blocks generated yet.'
            : aggregation.planPreview.take(3).map((b) => '- $b').join('\n');
        return 'PLAN SNAPSHOT\n\nPlan preview blocks: ${aggregation.planPreview.length}\n\nUpcoming blocks:\n$blocks\n\nPrompt: "what should I move or drop to reduce pressure today?"';
      case '/milestones':
        final MilestoneSummary summary = ref.read(milestoneSummaryProvider);
        final List<MilestoneEntity> overdue = ref.read(
          milestoneOverdueProvider,
        );
        final List<MilestoneEntity> upcoming = ref.read(
          milestoneUpcomingProvider,
        );
        final List<MilestoneRisk> risks = ref.read(milestoneRisksProvider);
        final List<String> topMilestones =
            (ref.read(milestonesProvider).asData?.value ??
                    const <MilestoneEntity>[])
                .take(3)
                .map(
                  (MilestoneEntity item) =>
                      '${item.title} (${item.completionPercent.round()}%)',
                )
                .toList(growable: false);
        final String topText = topMilestones.isEmpty
            ? 'No milestones created yet.'
            : topMilestones.map((String item) => '- $item').join('\n');
        return 'MILESTONES SNAPSHOT\n\n'
            'Total: ${summary.total}\n'
            'Active: ${summary.active}\n'
            'Completed: ${summary.completed}\n'
            'Overdue: ${summary.overdue}\n'
            'Upcoming: ${summary.upcoming}\n'
            'Health: ${summary.healthScore}%\n'
            'Momentum: ${summary.momentumScore}%\n'
            'Risk: ${summary.riskScore}%\n\n'
            'Closest: ${summary.closestMilestone?.title ?? 'No milestone'}\n'
            'Highest Priority: ${summary.highestPriority?.title ?? 'No milestone'}\n'
            'Next: ${summary.nextMilestone?.title ?? 'No upcoming milestone'}\n\n'
            'Overdue list: ${overdue.take(2).map((MilestoneEntity m) => m.title).join(' | ').trim().isEmpty ? 'None' : overdue.take(2).map((MilestoneEntity m) => m.title).join(' | ')}\n'
            'Upcoming list: ${upcoming.take(2).map((MilestoneEntity m) => m.title).join(' | ').trim().isEmpty ? 'None' : upcoming.take(2).map((MilestoneEntity m) => m.title).join(' | ')}\n'
            'Top risk: ${risks.isEmpty ? 'None' : '${risks.first.milestone.title} - ${risks.first.reason}'}\n\n'
            'Top milestones:\n$topText\n\n'
            'Prompt: "what milestone is next, what is overdue, and am I on track?"';
      case '/timeline':
        final int healthScore = ref.read(timelineHealthScoreProvider);
        final int riskScore = ref.read(timelineRiskScoreProvider);
        final int overdueCount = ref.read(timelineOverdueProvider).length;
        final int upcomingCount = ref.read(timelineUpcomingProvider).length;
        final int riskEventsCount = ref.read(timelineRiskEventsProvider).length;
        final int recommendationCount = ref
            .read(timelineRecommendationsProvider)
            .length;
        final List<TimelineEventEntity> upcomingEvents = ref.read(
          timelineUpcomingProvider,
        );
        final String nextDeadline = upcomingEvents.isEmpty
            ? 'No upcoming deadline in timeline data.'
            : upcomingEvents
                  .map((event) => event.title.toString().trim())
                  .firstWhere(
                    (String title) => title.isNotEmpty,
                    orElse: () => 'Upcoming deadline detected.',
                  );
        final List<String> events = aggregation.timeline
            .take(3)
            .map((e) => '${e.shortLabel}: ${e.title}')
            .toList(growable: false);
        final String eventsText = events.isEmpty
            ? 'No timeline events yet.'
            : events.map((e) => '- $e').join('\n');
        return 'TIMELINE SNAPSHOT\n\n'
            'Events: ${aggregation.timeline.length}\n'
            'Health: $healthScore%\n'
            'Risk: $riskScore%\n'
            'Overdue: $overdueCount\n'
            'Upcoming: $upcomingCount\n'
            'Risk events: $riskEventsCount\n'
            'Recommendations: $recommendationCount\n\n'
            'Next deadline: $nextDeadline\n\n'
            'Recent events:\n$eventsText\n\n'
            'Prompt: "what is overdue, what is next, and am I on track?"';
      case '/trajectory':
        return 'TRAJECTORY SNAPSHOT\n\nPressure: ${aggregation.trajectory.pressureIndex}\nMomentum: ${(aggregation.trajectory.momentum * 100).round()}%\nDivergence: ${aggregation.trajectory.behaviorDivergence}%\nAlert: ${aggregation.trajectory.alert}\n\nPrompt: "give me one action to improve momentum today."';
      default:
        return 'Module shortcut not recognized.';
    }
  }

  Future<void> _dispatchQuery(String text) async {
    try {
      final recommendation = await ref
          .read(aiControllerProvider)
          .sendMessage(text);
      if (!mounted) return;
      final String message = recommendation?.message.trim() ?? '';
      if (message.isEmpty || _isInvalidAssistantText(message)) {
        _safeSetState(() {
          _typing = false;
          _messages.add(
            const _Msg(
              text:
                  'No grounded response was generated. Ask with a specific feature and intent, for example: "show trajectory pressure", "summarize goals", or "plan next 3 tasks".',
              isUser: false,
              emotion: 'balanced',
            ),
          );
        });
        _scrollToBottom();
        return;
      }
      _safeSetState(() {
        _typing = false;
        _messages.add(
          _Msg(
            text: message,
            isUser: false,
            emotion: recommendation?.emotion ?? 'balanced',
            rationale: recommendation?.reasoning,
            confidence: recommendation?.confidence,
          ),
        );
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      _safeSetState(() {
        _typing = false;
        _messages.add(
          const _Msg(
            text:
                'Full intelligence context lock failed for that request. Retry, or target a module directly: tasks, progression, goals, memories, plan, emotions, or milestones.',
            isUser: false,
            emotion: 'cautious',
          ),
        );
      });
      _scrollToBottom();
    }
  }

  bool _isInvalidAssistantText(String value) {
    final String normalized = value.trim().toLowerCase();
    return normalized == 'undefined' ||
        normalized == 'null' ||
        normalized == 'undefined response' ||
        normalized == 'no response';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(extendedDomainBootstrapProvider);
    final int seededQueryCount = ref.watch(siQueriesProvider).length;
    final consoleModelAsync = ref.watch(siConsoleScreenModelProvider);
    final SIConsoleScreenModel? consoleModel = consoleModelAsync.asData?.value;
    final Object? consoleError = consoleModelAsync.asError?.error;
    final String? engineSnapshot = consoleModel?.engineSnapshot;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double keyboardInset = mediaQuery.viewInsets.bottom;
    final bool keyboardVisible = keyboardInset > 0;
    final double composerBottomInset = keyboardInset > 0
        ? keyboardInset
        : mediaQuery.padding.bottom;

    // The composer's own height isn't known until after it's laid out, so
    // the transcript's reserved bottom padding is measured, not guessed —
    // see _measureComposer.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureComposer());

    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgSiConsole,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: LoadingOverlay(
            isLoading: consoleModelAsync.isLoading && _messages.isEmpty,
            message: 'Initializing SI context...',
            child: Column(
              children: [
                _Header(
                  onBack: () {
                    unawaited(ref.read(voiceServiceProvider).stop());
                    ref.read(appFlowProvider.notifier).toNexus();
                  },
                  engineSnapshot: engineSnapshot,
                  seededQueryCount: seededQueryCount,
                  onSpeakSummary: () {
                    final List<_Msg> recentAssistant = _messages
                        .where((msg) => !msg.isUser)
                        .toList(growable: false);
                    final List<String> points = recentAssistant.reversed
                        .take(3)
                        .map((msg) => msg.text)
                        .toList(growable: false);
                    unawaited(
                      ref
                          .read(voiceServiceProvider)
                          .speakSummary(
                            title: 'SI console voice summary',
                            points: points,
                          ),
                    );
                  },
                  onSpeakAccessibility: () {
                    unawaited(_showAccessibilityGuide());
                  },
                ),
                Expanded(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _composerHeight,
                    builder: (context, composerHeight, _) {
                      final double composerReservedHeight = composerHeight;
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: (consoleError != null && _messages.isEmpty)
                                ? ErrorView(
                                    title: 'SI Context Error',
                                    message: PublicFailure.from(
                                      consoleError,
                                      fallback:
                                          'Strategic context is temporarily unavailable. Your saved work is unchanged; retry when ready.',
                                    ).message,
                                    onRetry: () {
                                      ref.invalidate(
                                        siConsoleScreenModelProvider,
                                      );
                                    },
                                  )
                                : ListView.builder(
                                    controller: _scroll,
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      composerReservedHeight +
                                          composerBottomInset,
                                    ),
                                    itemCount:
                                        _messages.length + (_typing ? 1 : 0),
                                    itemBuilder: (context, i) {
                                      if (_typing && i == _messages.length) {
                                        return _TypingIndicator(
                                          animation: _typingAnim,
                                        );
                                      }
                                      return _BubbleTile(
                                        msg: _messages[i],
                                        onReport: _messages[i].isUser
                                            ? null
                                            : () => unawaited(
                                                _showReportDialog(_messages[i]),
                                              ),
                                      );
                                    },
                                  ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: composerBottomInset,
                              ),
                              child: KeyedSubtree(
                                key: _composerKey,
                                child: _InputBar(
                                  controller: _input,
                                  onSend: _send,
                                  compact: keyboardVisible,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.seededQueryCount,
    required this.onSpeakSummary,
    required this.onSpeakAccessibility,
    this.engineSnapshot,
  });
  final VoidCallback onBack;
  final int seededQueryCount;
  final VoidCallback onSpeakSummary;
  final VoidCallback onSpeakAccessibility;
  final String? engineSnapshot;

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 760;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: 'Back to Smart Planner',
                button: true,
                child: GestureDetector(
                  onTap: onBack,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(11),
                    child: Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        seededQueryCount > 0
                            ? 'SI CONSOLE QRY:$seededQueryCount'
                            : 'SI CONSOLE',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // "SI" is the app's own coinage and appears nowhere in
                    // onboarding, so expand it here: a user arriving on this
                    // screen otherwise has no way to learn what it means.
                    const Text(
                      'Systems intelligence · on-device guidance',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.5,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              // No hardcoded 'ONLINE' chip here: it was a constant, so it
              // claimed a live connection even when the device was offline.
              // Real connectivity is surfaced by the global OfflineBanner.
            ],
          ),
          if (engineSnapshot != null) ...[
            const SizedBox(height: 4),
            Text(
              engineSnapshot ?? '',
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 1,
                color: Colors.white54,
              ),
              maxLines: 2,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              GestureDetector(
                onTap: onSpeakSummary,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 7 : 8,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.neonCyan.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.neonCyan.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.summarize_rounded,
                        size: 11,
                        color: AppColors.neonCyan,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'SUMMARY',
                        style: TextStyle(
                          fontSize: 8,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neonCyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: onSpeakAccessibility,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 7,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.accessibility_new_rounded,
                        size: 11,
                        color: Colors.white70,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'ACCESS',
                        style: TextStyle(
                          fontSize: 8,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message bubble
// ---------------------------------------------------------------------------

class _BubbleTile extends ConsumerWidget {
  const _BubbleTile({required this.msg, this.onReport});
  final _Msg msg;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isUser = msg.isUser;
    final String? emotion = msg.emotion;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _SIAvatar(emotion: msg.emotion),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF1E1330)
                        : const Color(0xFF0D1A2A),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: Border.all(
                      color: isUser
                          ? Colors.purple.withValues(alpha: 0.25)
                          : AppColors.neonCyan.withValues(alpha: 0.18),
                    ),
                    boxShadow: isUser
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.neonCyan.withValues(alpha: 0.06),
                              blurRadius: 12,
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser && emotion != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: _EmotionTag(emotion: emotion),
                        ),
                      TypingText(
                        msg.text,
                        key: ValueKey<String>(
                          'si-msg-${msg.isUser}-${msg.text}',
                        ),
                        animate: false,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color: isUser ? Colors.white70 : Colors.white,
                          fontFamily: isUser ? null : 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isUser &&
                    (msg.rationale != null || msg.confidence != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      [
                        if (msg.rationale != null &&
                            msg.rationale!.trim().isNotEmpty)
                          'Why this appears: ${msg.rationale!.trim()}',
                        if (msg.confidence != null)
                          'Confidence: ${(msg.confidence!.clamp(0, 1) * 100).round()}% — verify before acting.',
                      ].join('\n'),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (!isUser) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      Semantics(
                        button: true,
                        label: 'Read response aloud',
                        child: TextButton.icon(
                          onPressed: () => unawaited(
                            ref.read(voiceServiceProvider).speak(msg.text),
                          ),
                          icon: const Icon(Icons.volume_up_rounded, size: 16),
                          label: const Text('SPEAK'),
                        ),
                      ),
                      if (onReport != null)
                        Semantics(
                          button: true,
                          label: 'Report response',
                          child: TextButton.icon(
                            onPressed: onReport,
                            icon: const Icon(Icons.flag_outlined, size: 16),
                            label: const Text('REPORT'),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _SIAvatar extends StatelessWidget {
  const _SIAvatar({this.emotion});
  final String? emotion;

  Color get _color {
    switch (emotion) {
      case 'engaged':
        return Colors.blueAccent;
      case 'confident':
        return Colors.cyanAccent;
      case 'driven':
        return Colors.deepOrangeAccent;
      case 'cautious':
        return Colors.amberAccent;
      case 'strained':
        return Colors.redAccent;
      default:
        return AppColors.neonCyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0A1520),
        border: Border.all(color: _color.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: _color.withValues(alpha: 0.25), blurRadius: 8),
        ],
      ),
      child: Center(
        child: Text(
          'SI',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: _color,
          ),
        ),
      ),
    );
  }
}

class _EmotionTag extends StatelessWidget {
  const _EmotionTag({required this.emotion});
  final String emotion;

  Color get _color {
    switch (emotion) {
      case 'engaged':
        return Colors.blueAccent;
      case 'confident':
        return Colors.cyanAccent;
      case 'driven':
        return Colors.deepOrangeAccent;
      case 'cautious':
        return Colors.amberAccent;
      case 'strained':
        return Colors.redAccent;
      default:
        return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(
        emotion.toUpperCase(),
        style: TextStyle(
          fontSize: 8,
          letterSpacing: 1.5,
          color: _color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Typing indicator
// ---------------------------------------------------------------------------

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _SIAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1A2A),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(
                color: AppColors.neonCyan.withValues(alpha: 0.18),
              ),
            ),
            child: AnimatedBuilder(
              animation: animation,
              builder: (_, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final double phase = (animation.value - i * 0.2).clamp(
                      0.0,
                      1.0,
                    );
                    final double opacity =
                        0.3 + 0.7 * math.sin(phase * math.pi);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.neonCyan,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input bar
// ---------------------------------------------------------------------------

class _InputBar extends ConsumerWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    this.compact = false,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool compact;

  static const List<String> _commands = <String>[
    '/help',
    '/status',
    '/tasks',
    '/goals',
    '/plan',
    '/timeline',
    '/trajectory',
  ];

  void _insertShortcut(String shortcut) {
    controller
      ..text = '$shortcut '
      ..selection = TextSelection.collapsed(offset: shortcut.length + 1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VoiceState voice = ref.watch(voiceControllerProvider);
    final bool listening = voice.isListening;

    // Recognized speech populates the query box for explicit review and
    // send - it is never auto-sent or routed as a shortcut.
    ref.listen<VoiceState>(voiceControllerProvider, (previous, next) {
      final bool stoppedListening =
          (previous?.isListening ?? false) && !next.isListening;
      if (stoppedListening && next.recognizedText.trim().isNotEmpty) {
        controller.text = next.recognizedText.trim();
        ref.read(voiceControllerProvider.notifier).clearRecognizedText();
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool forceCompact =
            constraints.hasBoundedHeight && constraints.maxHeight < 150;
        final bool effectiveCompact = compact || forceCompact;

        return Container(
          padding: EdgeInsets.fromLTRB(
            16,
            effectiveCompact ? 8 : 10,
            16,
            effectiveCompact ? 10 : 16,
          ),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!effectiveCompact) ...[
                  const Text(
                    'Quick shortcuts',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _commands
                          .map(
                            (shortcut) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () {
                                  _insertShortcut(shortcut);
                                  onSend();
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.neonCyan.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppColors.neonCyan.withValues(
                                        alpha: 0.28,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    shortcut,
                                    style: const TextStyle(
                                      color: AppColors.neonCyan,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        cursorColor: AppColors.neonCyan,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Query the system...',
                          hintStyle: const TextStyle(
                            color: Colors.white24,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0A1520),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: AppColors.neonCyan.withValues(alpha: 0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: AppColors.neonCyan.withValues(alpha: 0.15),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: AppColors.neonCyan.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        onSubmitted: (_) => onSend(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Semantics(
                      label: listening
                          ? 'Stop voice input'
                          : 'Start voice input',
                      button: true,
                      child: GestureDetector(
                        onTap: () async {
                          if (listening) {
                            await ref
                                .read(voiceControllerProvider.notifier)
                                .stopListening();
                            return;
                          }
                          await ref
                              .read(voiceControllerProvider.notifier)
                              .startListening();
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: listening
                                ? AppColors.neonCyan.withValues(alpha: 0.22)
                                : AppColors.neonCyan.withValues(alpha: 0.12),
                            border: Border.all(
                              color: AppColors.neonCyan.withValues(
                                alpha: listening ? 0.6 : 0.4,
                              ),
                            ),
                          ),
                          child: Icon(
                            listening ? Icons.mic : Icons.mic_none_rounded,
                            color: AppColors.neonCyan,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Semantics(
                      label: 'Send query',
                      button: true,
                      child: GestureDetector(
                        onTap: onSend,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.neonCyan.withValues(alpha: 0.12),
                            border: Border.all(
                              color: AppColors.neonCyan.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: AppColors.neonCyan,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
