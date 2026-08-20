import 'dart:async';
import 'dart:math' as math;

import 'package:fantastic_guacamole/app/router/app_view_navigation.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/errors/public_failure.dart';
import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/value_objects/ai_content_report_reason.dart';
import 'package:fantastic_guacamole/features/si_console/ui/models/si_console_message.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_console_query_controller.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/providers/ai_content_report_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/milestones_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_console_thread_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/crisis_dialog.dart';
import 'package:fantastic_guacamole/ui/widgets/typing_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

String _evidenceStrengthLabel(double value) {
  final double bounded = value.clamp(0, 1).toDouble();
  if (bounded >= .8) return 'Strong';
  if (bounded >= .55) return 'Moderate';
  return 'Limited';
}

class _Msg {
  const _Msg({
    required this.text,
    required this.isUser,
    this.emotion,
    this.rationale,
    this.confidence,
    this.processingMode = AIProcessingMode.unknown,
    this.systemPanel = false,
  });
  final String text;
  final bool isUser;
  final String? emotion;
  final String? rationale;
  final double? confidence;
  final AIProcessingMode processingMode;
  final bool systemPanel;

  SIConsoleMessage toStoredMessage() => SIConsoleMessage(
    text: text,
    isUser: isUser,
    emotion: emotion,
    createdAt: DateTime.now().toUtc(),
  );

  static _Msg fromStoredMessage(SIConsoleMessage message) => _Msg(
    text: message.text,
    isUser: message.isUser,
    emotion: message.emotion,
  );
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
  bool _threadRestored = false;
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
                systemPanel: true,
              ),
            );
          });
          _schedulePersistThread();
          _scrollToBottom();
        });
    _typingAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreThread());
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

  Future<void> _restoreThread() async {
    if (_threadRestored) return;
    final List<SIConsoleMessage> stored = await ref.read(
      siConsoleThreadProvider.future,
    );
    if (!mounted || _threadRestored) return;
    _safeSetState(() {
      _threadRestored = true;
      if (stored.isNotEmpty) {
        _messages
          ..clear()
          ..addAll(stored.map(_Msg.fromStoredMessage));
        return;
      }
      _messages.add(
        const _Msg(
          text:
              'Strategic Intelligence is ready. I will use only the sources currently available, such as tasks, goals, Timeline, Progression, and saved preferences. '
              'Responses may be limited when a source is missing, stale, or offline. Type "help" to see available shortcuts.',
          isUser: false,
          emotion: 'confident',
          systemPanel: true,
        ),
      );
    });
    _scrollToBottom();
  }

  void _schedulePersistThread() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final List<SIConsoleMessage> persisted = _messages
          .where((message) => message.text.trim().isNotEmpty)
          .map((message) => message.toStoredMessage())
          .toList(growable: false);
      unawaited(ref.read(siConsoleThreadStoreProvider).save(persisted));
    });
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
              backgroundColor: const Color(0xFF0C1420),
              surfaceTintColor: Colors.transparent,
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
      'Use Back to return to Nexus.',
    ];
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF0C1420),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20),
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
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Use these controls for readable and spoken guidance.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '1. Type a prompt, then send.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '2. Summary reads recent assistant responses.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '3. Speak reads one response aloud.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '4. Back returns to Nexus.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
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

  void _addShortcutResponse({
    required String query,
    required String response,
    String emotion = 'engaged',
  }) {
    _safeSetState(() {
      _messages.add(_Msg(text: query, isUser: true));
      _messages.add(
        _Msg(
          text: response,
          isUser: false,
          emotion: emotion,
          systemPanel: true,
          processingMode: AIProcessingMode.onDevice,
        ),
      );
    });
    _schedulePersistThread();
    _scrollToBottom();
  }

  void _send() {
    final String text = _input.text.trim();
    if (text.isEmpty) return;
    if (_typing) return;

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
    _schedulePersistThread();
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
      _addShortcutResponse(
        query: text,
        response:
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
            '- SI Console is analysis and guidance, not data entry.\n\n'
            'High-signal prompts SI responds well to:\n'
            '- "List my 3 newest tasks and what to do first."\n'
            '- "Did I create a task just now? Show the latest task title."\n'
            '- "Summarize trajectory pressure and one corrective action."\n'
            '- "Show plan risks for today and 3 next actions."\n'
            '- "Summarize goals at risk and what to do next."\n'
            '- "Compare current self to future self."\n\n'
            'Tip: use a shortcut first, then add intent. Example: /tasks what should I execute now?',
      );
      return true;
    }

    if (normalized == '/status' || normalized == 'status') {
      final String status = (aggregation == null)
          ? 'SI STATUS\n\n'
                'Local data sources are still loading. Retry /status in a second.\n'
                'If this persists, open /tasks or /plan to inspect the affected source.'
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

      _addShortcutResponse(query: text, response: status);
      return true;
    }

    if (shortcut == '/tasks' ||
        shortcut == '/goals' ||
        shortcut == '/milestones' ||
        shortcut == '/plan' ||
        shortcut == '/timeline' ||
        shortcut == '/trajectory') {
      final String response = _localSurfaceSummary(shortcut, aggregation);
      _addShortcutResponse(query: text, response: response);
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
        final String? selectedTaskId =
            aggregation.planningDecision.selectedTask?.id;
        final String? selectedTaskTitle =
            aggregation.planningDecision.selectedTask?.title;
        final List<String> active = aggregation.tasks
            .where((task) => task.id != selectedTaskId)
            .take(3)
            .map((task) => task.title)
            .toList(growable: false);
        final String activeText = active.isEmpty
            ? 'No active tasks yet.'
            : active.map((task) => '- $task').join('\n');
        return 'TASKS SNAPSHOT\n\n'
            'Active tasks: ${aggregation.tasks.length}\n\n'
            'Recommended next:\n'
            '${selectedTaskTitle == null || selectedTaskTitle.trim().isEmpty ? 'No ranked task available yet.' : '- $selectedTaskTitle'}\n\n'
            'Why:\n${aggregation.planningDecision.rationale}\n\n'
            'Other active tasks:\n$activeText\n\n'
            'Prompt: "why this task first, and what is the smallest next step?"';
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
              systemPanel: true,
              processingMode: AIProcessingMode.onDevice,
            ),
          );
        });
        _schedulePersistThread();
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
            processingMode:
                recommendation?.processingMode ?? AIProcessingMode.unknown,
          ),
        );
      });
      _schedulePersistThread();
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
            systemPanel: true,
            processingMode: AIProcessingMode.onDeviceFallback,
          ),
        );
      });
      _schedulePersistThread();
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
          child: Column(
            children: [
              _Header(
                onBack: () {
                  unawaited(ref.read(voiceServiceProvider).stop());
                  goToAppView(context, ref, AppView.nexus);
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
              _ContextStatusBanner(
                loading: consoleModelAsync.isLoading,
                error: consoleError,
                model: consoleModel,
                onRetry: () => ref.invalidate(siConsoleScreenModelProvider),
              ),
              Expanded(
                child: ValueListenableBuilder<double>(
                  valueListenable: _composerHeight,
                  builder: (context, composerHeight, _) {
                    final double composerReservedHeight = composerHeight;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: ListView.builder(
                            controller: _scroll,
                            padding: EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              composerReservedHeight + composerBottomInset,
                            ),
                            itemCount: _messages.length + (_typing ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (_typing && i == _messages.length) {
                                return _TypingIndicator(animation: _typingAnim);
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
                                busy: _typing,
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
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _ContextStatusBanner extends StatelessWidget {
  const _ContextStatusBanner({
    required this.loading,
    required this.error,
    required this.model,
    required this.onRetry,
  });

  final bool loading;
  final Object? error;
  final SIConsoleScreenModel? model;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final String message;
    final IconData icon;
    final Color accent;
    if (error != null) {
      message = PublicFailure.from(
        error!,
        fallback:
            'Strategic context is temporarily unavailable. Saved work is unchanged.',
      ).message;
      icon = Icons.error_outline_rounded;
      accent = Colors.amberAccent;
    } else if (loading) {
      message = 'Initializing SI context...';
      icon = Icons.sync_rounded;
      accent = AppColors.neonCyan;
    } else {
      final SIStateAggregation? aggregation = model?.aggregation;
      message = aggregation == null
          ? 'Evidence state unavailable.'
          : 'Evidence ready: ${aggregation.tasks.length} tasks, ${aggregation.goals.length} goals, ${aggregation.timeline.length} timeline events.';
      icon = Icons.verified_rounded;
      accent = Colors.greenAccent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF07111C),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          if (error != null) ...<Widget>[
            const SizedBox(width: 8),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}

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
        color: Color(0xFF07111C),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: 'Back to Nexus',
                child: IconButton(
                  onPressed: onBack,
                  tooltip: 'Back to Nexus',
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white70,
                    size: 20,
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
                      'Systems intelligence - source-aware guidance',
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
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onSpeakSummary,
                  icon: const Icon(Icons.summarize_rounded, size: 16),
                  label: Text(compact ? 'Summary' : 'Read Summary'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.neonCyan,
                    side: const BorderSide(color: AppColors.neonCyan),
                    backgroundColor: const Color(0xFF102436),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onSpeakAccessibility,
                  icon: const Icon(Icons.accessibility_new_rounded, size: 16),
                  label: Text(compact ? 'Access' : 'Accessibility'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white30),
                    backgroundColor: const Color(0xFF161D27),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
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
    final bool systemPanel = msg.systemPanel && !isUser;
    final Color bubbleColor = isUser
        ? const Color(0xFF1A1330)
        : systemPanel
        ? const Color(0xFF101A24)
        : const Color(0xFF0B1622);
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
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(systemPanel ? 8 : 16),
                      topRight: Radius.circular(systemPanel ? 8 : 16),
                      bottomLeft: Radius.circular(isUser ? 16 : 6),
                      bottomRight: Radius.circular(isUser ? 6 : 16),
                    ),
                    border: Border.all(
                      color: isUser
                          ? Colors.purple.withValues(alpha: 0.25)
                          : systemPanel
                          ? Colors.white24
                          : AppColors.neonCyan.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser && emotion != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: _EmotionTag(emotion: emotion),
                        ),
                      if (!isUser &&
                          msg.processingMode != AIProcessingMode.unknown)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _ProcessingModeTag(mode: msg.processingMode),
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
                          fontFamily: null,
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
                          '${msg.processingMode == AIProcessingMode.external ? 'Assistant confidence signal' : 'Heuristic evidence strength'}: ${_evidenceStrengthLabel(msg.confidence!)} — not a calibrated probability; verify before acting.',
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

class _ProcessingModeTag extends StatelessWidget {
  const _ProcessingModeTag({required this.mode});

  final AIProcessingMode mode;

  String get _label {
    switch (mode) {
      case AIProcessingMode.external:
        return 'External AI';
      case AIProcessingMode.onDevice:
        return 'On device';
      case AIProcessingMode.onDeviceFallback:
        return 'On-device fallback';
      case AIProcessingMode.unknown:
        return 'Processing unknown';
    }
  }

  Color get _color {
    switch (mode) {
      case AIProcessingMode.external:
        return Colors.deepPurpleAccent;
      case AIProcessingMode.onDevice:
        return Colors.greenAccent;
      case AIProcessingMode.onDeviceFallback:
        return Colors.amberAccent;
      case AIProcessingMode.unknown:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Processing mode: $_label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF07111C),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _color.withValues(alpha: 0.55)),
        ),
        child: Text(
          _label,
          style: TextStyle(
            color: _color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
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
    this.busy = false,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool compact;
  final bool busy;

  static const List<({String label, String shortcut})> _commands =
      <({String label, String shortcut})>[
        (label: 'Help', shortcut: '/help'),
        (label: 'Status', shortcut: '/status'),
        (label: 'Tasks', shortcut: '/tasks'),
        (label: 'Goals', shortcut: '/goals'),
        (label: 'Plan', shortcut: '/plan'),
        (label: 'Milestones', shortcut: '/milestones'),
        (label: 'Timeline', shortcut: '/timeline'),
        (label: 'Trajectory', shortcut: '/trajectory'),
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
            color: Color(0xFF07111C),
            border: Border(top: BorderSide(color: Colors.white24)),
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!effectiveCompact) ...[
                  const Text(
                    'Explore evidence',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
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
                                onTap: busy
                                    ? null
                                    : () {
                                        _insertShortcut(shortcut.shortcut);
                                        onSend();
                                      },
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 44,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: busy
                                        ? const Color(0xFF151B22)
                                        : const Color(0xFF102436),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: busy
                                          ? Colors.white12
                                          : AppColors.neonCyan,
                                    ),
                                  ),
                                  child: Text(
                                    shortcut.label,
                                    style: TextStyle(
                                      color: busy
                                          ? Colors.white38
                                          : AppColors.neonCyan,
                                      fontSize: 12,
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
                        maxLines: 4,
                        enabled: !busy,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        cursorColor: AppColors.neonCyan,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Query the system...',
                          hintStyle: const TextStyle(
                            color: Colors.white60,
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
                        onSubmitted: (_) {
                          if (!busy) onSend();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Semantics(
                      label: listening
                          ? 'Stop voice input'
                          : 'Start voice input',
                      button: true,
                      child: GestureDetector(
                        onTap: busy
                            ? null
                            : () async {
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
                                : busy
                                ? const Color(0xFF151B22)
                                : const Color(0xFF102436),
                            border: Border.all(
                              color: busy ? Colors.white12 : AppColors.neonCyan,
                            ),
                          ),
                          child: Icon(
                            listening ? Icons.mic : Icons.mic_none_rounded,
                            color: busy ? Colors.white38 : AppColors.neonCyan,
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
                        onTap: busy ? null : onSend,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: busy
                                ? const Color(0xFF151B22)
                                : const Color(0xFF102436),
                            border: Border.all(
                              color: busy ? Colors.white12 : AppColors.neonCyan,
                            ),
                          ),
                          child: Icon(
                            busy
                                ? Icons.hourglass_top_rounded
                                : Icons.send_rounded,
                            color: busy ? Colors.white38 : AppColors.neonCyan,
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
