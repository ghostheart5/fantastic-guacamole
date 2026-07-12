import 'dart:async';
import 'dart:math' as math;

import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_console_query_controller.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/models/core_values_models.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/models/soul_map_models.dart';
import 'package:fantastic_guacamole/state/providers/core_values_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/milestones_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/soul_map_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
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
  const _Msg({required this.text, required this.isUser, this.emotion});
  final String text;
  final bool isUser;
  final String? emotion;
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
    with SingleTickerProviderStateMixin {
  final List<_Msg> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _typing = false;
  late final AnimationController _typingAnim;
  StreamSubscription<GoalLifecycleEvent>? _goalEventSubscription;

  void _runAfterBuild(VoidCallback action) {
    if (!mounted) return;
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
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
    AppAnalytics.track('si_opened');
    _goalEventSubscription = ref.read(eventBusProvider).on<GoalLifecycleEvent>().listen((event) {
      if (!mounted) {
        return;
      }
      _safeSetState(() {
        _messages.add(
          _Msg(
            text: 'GOAL SYNC: ${event.action.toUpperCase()} ${event.title}',
            isUser: false,
            emotion: 'focused',
          ),
        );
      });
      _scrollToBottom();
    });
    _typingAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();

    // Greeting after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addSI(
        'System online. Strategic Intelligence interface active.\n'
        'I have access to tasks, progression, goals, memories, day plan, flowmap, emotions, soul map, milestones, and console history. '
        'Ask me anything - or type "help" to see available commands.',
        emotion: 'confident',
      );
    });
  }

  @override
  void dispose() {
    _typingAnim.dispose();
    _input.dispose();
    _scroll.dispose();
    unawaited(ref.read(voiceServiceProvider).stop());
    unawaited(_goalEventSubscription?.cancel());
    super.dispose();
  }

  void _addSI(String text, {String emotion = 'balanced'}) {
    _safeSetState(() => _messages.add(_Msg(text: text, isUser: false, emotion: emotion)));
    _scrollToBottom();
  }

  Future<void> _showAccessibilityGuide() async {
    if (!mounted) {
      return;
    }
    const List<String> controls = <String>[
      'Type a prompt in the input field, then tap send.',
      'Use Summary to hear recent assistant responses.',
      'Use Speak on assistant bubbles to read aloud.',
      'Use Back to return to Smart Coach.',
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
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
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
                  '4. Back returns to Smart Coach',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
    unawaited(
      ref
          .read(voiceServiceProvider)
          .speakAccessibilityHint(surface: 'SI Console', controls: controls),
    );
  }

  void _send() {
    final String text = _input.text.trim();
    if (text.isEmpty) return;

    if (_handleLocalCommand(text)) {
      _input.clear();
      return;
    }

    if (ref.read(siConsoleQueryControllerProvider).detectsCrisis(text)) {
      showCrisisDialog(context);
      return;
    }
    _input.clear();

    _safeSetState(() => _messages.add(_Msg(text: text, isUser: true)));
    _scrollToBottom();
    _safeSetState(() => _typing = true);

    _dispatchQuery(text);
  }

  bool _handleLocalCommand(String text) {
    final String normalized = text.trim().toLowerCase();
    final String command = normalized.split(RegExp(r'\s+')).first;
    final SIConsoleScreenModel? consoleModel = ref.read(siConsoleScreenModelProvider).asData?.value;
    final SIStateAggregation? aggregation = consoleModel?.aggregation;

    if (normalized == '/help' || normalized == 'help') {
      _safeSetState(() {
        _messages.add(_Msg(text: text, isUser: true));
        _messages.add(
          const _Msg(
            text:
                'SI COMMAND GUIDE\n\n'
                'Quick commands:\n'
                '- /tasks: inspect active tasks and next actions\n'
                '- /goals: summarize goals and drift\n'
                '- /milestones: summarize checkpoint health, risk, and next target\n'
                '- /values: show core values alignment and neglected value\n'
                '- /soulmap: analyze identity, purpose, and life direction\n'
                '- /soulmap compare: compare current self to future self\n'
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
                'Tip: use a command first, then add intent. Example: /tasks what should I execute now?',
            isUser: false,
            emotion: 'focused',
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
                '- core values overall: ${ref.read(coreValuesAlignmentProvider).overall}%\n'
                '- soulmap overall: ${ref.read(soulMapAlignmentProvider).overall}%\n'
                '- flowmap: ${aggregation.flowmapNodes.length}\n'
                '- plan preview blocks: ${aggregation.planPreview.length}\n\n'
                'Trajectory:\n'
                '- pressure: ${aggregation.trajectory.pressureIndex}\n'
                '- momentum: ${(aggregation.trajectory.momentum * 100).round()}%\n'
                '- divergence: ${aggregation.trajectory.behaviorDivergence}%\n\n'
                'Use /tasks, /goals, /milestones, /values, /soulmap, /soulmap compare, /plan, /timeline, /trajectory for module-specific responses.';

      _safeSetState(() {
        _messages.add(_Msg(text: text, isUser: true));
        _messages.add(_Msg(text: status, isUser: false, emotion: 'focused'));
      });
      _scrollToBottom();
      return true;
    }

    if (command == '/tasks' ||
        command == '/goals' ||
        command == '/milestones' ||
        command == '/values' ||
        command == '/soulmap' ||
        command == '/plan' ||
        command == '/timeline' ||
        command == '/trajectory') {
      final bool compareSoulMap = normalized.startsWith('/soulmap compare');
      final String response = _localSurfaceSummary(command, aggregation);
      _safeSetState(() {
        _messages.add(_Msg(text: text, isUser: true));
        _messages.add(
          _Msg(
            text: compareSoulMap ? _localSoulMapCompareSummary(aggregation) : response,
            isUser: false,
            emotion: 'focused',
          ),
        );
      });
      _scrollToBottom();
      return true;
    }

    return false;
  }

  String _localSurfaceSummary(String command, SIStateAggregation? aggregation) {
    if (aggregation == null) {
      return 'SI is still loading module data. Retry the command in a second.';
    }

    switch (command) {
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
        final String topText = top.isEmpty ? 'No goals found.' : top.map((g) => '- $g').join('\n');
        return 'GOALS SNAPSHOT\n\nGoals: ${aggregation.goals.length}\n\nTop goals:\n$topText\n\nPrompt: "which goal is drifting and what is the next corrective action?"';
      case '/plan':
        final String blocks = aggregation.planPreview.isEmpty
            ? 'No adaptive blocks generated yet.'
            : aggregation.planPreview.take(3).map((b) => '- $b').join('\n');
        return 'PLAN SNAPSHOT\n\nPlan preview blocks: ${aggregation.planPreview.length}\n\nUpcoming blocks:\n$blocks\n\nPrompt: "what should I move or drop to reduce pressure today?"';
      case '/milestones':
        final MilestoneSummary summary = ref.read(milestoneSummaryProvider);
        final List<MilestoneEntity> overdue = ref.read(milestoneOverdueProvider);
        final List<MilestoneEntity> upcoming = ref.read(milestoneUpcomingProvider);
        final List<MilestoneRisk> risks = ref.read(milestoneRisksProvider);
        final List<String> topMilestones =
            (ref.read(milestonesProvider).asData?.value ?? const <MilestoneEntity>[])
                .take(3)
                .map((MilestoneEntity item) => '${item.title} (${item.completionPercent.round()}%)')
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
      case '/values':
        final CoreValuesAlignment values = ref.read(coreValuesAlignmentProvider);
        final List<String> rows = CoreValueType.values
            .map(
              (CoreValueType value) =>
                  '${coreValueTitle(value)}: ${values.scores[value]?.score ?? 0}%',
            )
            .toList(growable: false);
        return 'CORE VALUES ALIGNMENT\n\n'
            '${rows.join('\n')}\n\n'
            'Strongest: ${coreValueTitle(values.strongest)}\n'
            'Most Neglected: ${coreValueTitle(values.mostNeglected)}\n'
            'Overall: ${values.overall}%\n\n'
            'Recommended Action:\n'
            '${values.recommendations.firstWhere((String line) => line.toLowerCase().contains('schedule one action'), orElse: () => 'Schedule one action this week aligned to your neglected value.')}\n\n'
            'Prompt: "analyze my life by core values alignment"';
      case '/soulmap':
        final SoulMapAlignment soulMap = ref.read(soulMapAlignmentProvider);
        final int purpose = soulMap.scores[SoulMapDimension.purpose]?.score ?? 0;
        final int identity = soulMap.scores[SoulMapDimension.identity]?.score ?? 0;
        final int values = soulMap.scores[SoulMapDimension.coreValues]?.score ?? 0;
        final int futureSelf = soulMap.scores[SoulMapDimension.futureSelf]?.score ?? 0;
        final String strongest = soulMapDimensionTitle(soulMap.strongest);
        final String weakest = soulMapDimensionTitle(soulMap.weakest);
        final String action = soulMap.recommendations.firstWhere(
          (String line) => line.toLowerCase().contains('schedule one concrete action'),
          orElse: () => 'Schedule one concrete action this week to strengthen $weakest.',
        );
        return 'SOULMAP ANALYSIS\n\n'
            'Purpose Alignment: $purpose%\n'
            'Identity Alignment: $identity%\n'
            'Values Alignment: $values%\n'
            'Future Self Progress: $futureSelf%\n\n'
            'Strongest Area:\n$strongest\n\n'
            'Weakest Area:\n$weakest\n\n'
            'Recommendation:\n$action\n\n'
            'Tip: run /soulmap compare to compare current self vs future self.\n\n'
            'Prompt: "analyze my life"';
      case '/timeline':
        final int healthScore = ref.read(timelineHealthScoreProvider);
        final int riskScore = ref.read(timelineRiskScoreProvider);
        final int overdueCount = ref.read(timelineOverdueProvider).length;
        final int upcomingCount = ref.read(timelineUpcomingProvider).length;
        final int riskEventsCount = ref.read(timelineRiskEventsProvider).length;
        final int recommendationCount = ref.read(timelineRecommendationsProvider).length;
        final List<TimelineEventEntity> upcomingEvents = ref.read(timelineUpcomingProvider);
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
        return 'Module command not recognized.';
    }
  }

  String _localSoulMapCompareSummary(SIStateAggregation? aggregation) {
    if (aggregation == null) {
      return 'SI is still loading module data. Retry the command in a second.';
    }

    final SoulMapFutureSelfComparison compare = ref.read(soulMapFutureSelfComparisonProvider);
    return 'SOULMAP CURRENT VS FUTURE SELF\n\n'
        'Current Self Alignment: ${compare.currentSelfAlignment}%\n'
        'Future Self Readiness: ${compare.futureSelfReadiness}%\n'
        'Gap: ${compare.gap}%\n'
        'Stance: ${compare.stance}\n\n'
        'Recommendation:\n${compare.recommendation}\n\n'
        'Prompt: "compare current self to future self"';
  }

  Future<void> _dispatchQuery(String text) async {
    try {
      final recommendation = await ref.read(aiControllerProvider).sendMessage(text);
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
          _Msg(text: message, isUser: false, emotion: recommendation?.emotion ?? 'balanced'),
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
                'Full intelligence context lock failed for that request. Retry, or target a module directly: tasks, progression, goals, memories, plan, flowmap, emotions, soul map, or milestones.',
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
    final double composerMaxHeight = keyboardVisible ? 120 : 220;
    final double composerReservedHeight = composerMaxHeight;

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
                    ref.read(appFlowProvider.notifier).toCoach();
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
                          .speakSummary(title: 'SI console voice summary', points: points),
                    );
                  },
                  onSpeakAccessibility: () {
                    unawaited(_showAccessibilityGuide());
                  },
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: (consoleError != null && _messages.isEmpty)
                            ? ErrorView(
                                title: 'SI Context Error',
                                message: consoleError.toString(),
                                onRetry: () {
                                  ref.invalidate(siConsoleScreenModelProvider);
                                },
                              )
                            : ListView.builder(
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
                                  return _BubbleTile(msg: _messages[i]);
                                },
                              ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: composerBottomInset),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: composerMaxHeight),
                            child: _InputBar(
                              controller: _input,
                              onSend: _send,
                              compact: keyboardVisible,
                            ),
                          ),
                        ),
                      ),
                    ],
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
              GestureDetector(
                onTap: onBack,
                child: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 18),
              ),
              const SizedBox(width: 12),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    seededQueryCount > 0 ? 'SI CONSOLE QRY:$seededQueryCount' : 'SI CONSOLE',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'ONLINE',
                style: TextStyle(fontSize: 9, letterSpacing: 2, color: Colors.greenAccent),
              ),
            ],
          ),
          if (engineSnapshot != null) ...[
            const SizedBox(height: 4),
            Text(
              engineSnapshot ?? '',
              style: const TextStyle(fontSize: 8, letterSpacing: 1, color: Colors.white54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              GestureDetector(
                onTap: onSpeakSummary,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.neonCyan.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.summarize_rounded, size: 11, color: AppColors.neonCyan),
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
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.accessibility_new_rounded, size: 11, color: Colors.white70),
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
  const _BubbleTile({required this.msg});
  final _Msg msg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isUser = msg.isUser;
    final String? emotion = msg.emotion;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[_SIAvatar(emotion: msg.emotion), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF1E1330) : const Color(0xFF0D1A2A),
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
                        key: ValueKey<String>('si-msg-${msg.isUser}-${msg.text}'),
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
                if (!isUser) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => unawaited(ref.read(voiceServiceProvider).speak(msg.text)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.neonCyan.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_up_rounded, color: AppColors.neonCyan, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'SPEAK',
                            style: TextStyle(
                              color: AppColors.neonCyan,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
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
      case 'focused':
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
        boxShadow: [BoxShadow(color: _color.withValues(alpha: 0.25), blurRadius: 8)],
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
      case 'focused':
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
              border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.18)),
            ),
            child: AnimatedBuilder(
              animation: animation,
              builder: (_, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final double phase = (animation.value - i * 0.2).clamp(0.0, 1.0);
                    final double opacity = 0.3 + 0.7 * math.sin(phase * math.pi);
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

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend, this.compact = false});
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

  void _insertCommand(String command) {
    controller
      ..text = '$command '
      ..selection = TextSelection.collapsed(offset: command.length + 1);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool forceCompact = constraints.hasBoundedHeight && constraints.maxHeight < 150;
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
                    'Quick commands',
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
                            (command) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () {
                                  _insertCommand(command);
                                  onSend();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.neonCyan.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppColors.neonCyan.withValues(alpha: 0.28),
                                    ),
                                  ),
                                  child: Text(
                                    command,
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
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        cursorColor: AppColors.neonCyan,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Query the system...',
                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFF0A1520),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    GestureDetector(
                      onTap: onSend,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.neonCyan.withValues(alpha: 0.12),
                          border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.send_rounded, color: AppColors.neonCyan, size: 18),
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
