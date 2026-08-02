import 'package:fantastic_guacamole/state/providers/goal_success_probability_provider.dart';
import 'package:fantastic_guacamole/state/providers/predictive_risk_provider.dart';
import 'package:fantastic_guacamole/state/providers/memory_intelligence_provider.dart';
import 'package:fantastic_guacamole/features/si_console/ui/models/si_console_commands.dart';
import 'package:fantastic_guacamole/features/si_console/ui/models/si_console_message.dart';
import 'package:fantastic_guacamole/features/si_console/ui/models/si_console_prompt_copy.dart';
import 'package:fantastic_guacamole/features/si_console/ui/models/si_response_frame.dart';
import 'package:fantastic_guacamole/features/si_console/ui/models/si_console_response_validator.dart';
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
import 'package:fantastic_guacamole/state/providers/explainable_si_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/milestones_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_simulation_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/state/providers/adaptive_replanning_provider.dart';
import 'package:fantastic_guacamole/state/providers/cognitive_twin_provider.dart';
import 'package:fantastic_guacamole/state/providers/future_self_simulator_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_drift_provider.dart';
import 'package:fantastic_guacamole/state/providers/future_decision_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/future_timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/alternative_life_paths_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_evolution_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_weekly_planner_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_daily_planner_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_focus_scheduler_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_review_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_life_optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/soul_map_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/system/voice/voice_service.dart';
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
  final List<SIConsoleMessage> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late final VoiceService _voiceService;
  bool _typing = false;
  late final AnimationController _typingAnim;
  StreamSubscription<GoalLifecycleEvent>? _goalEventSubscription;
  StreamSubscription<TaskLifecycleEvent>? _taskEventSubscription;

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
    AppAnalytics.track('si_opened');
    _voiceService = ref.read(voiceServiceProvider);
    _goalEventSubscription = ref
        .read(eventBusProvider)
        .on<GoalLifecycleEvent>()
        .listen((event) {
          if (!mounted) {
            return;
          }
          _safeSetState(() {
            _messages.add(
              SIConsoleMessage(
                text: 'Goal sync: ${event.action.toLowerCase()} ${event.title}',
                isUser: false,
                emotion: 'focused',
              ),
            );
          });
          _scrollToBottom();
        });
    _taskEventSubscription = ref
        .read(eventBusProvider)
        .on<TaskLifecycleEvent>()
        .listen((event) {
          if (!mounted) {
            return;
          }
          _safeSetState(() {
            _messages.add(
              SIConsoleMessage(
                text:
                    'Task sync: ${event.action.toLowerCase()} ${event.title} (${event.actionSource.toLowerCase()})',
                isUser: false,
                emotion: 'focused',
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
        'SI Console is ready.\n'
        'I can help with tasks, goals, timeline, momentum, and planning context. '
        'Ask a question, or type "help" to see the available commands.',
        emotion: 'confident',
      );
    });
  }

  @override
  void dispose() {
    _typingAnim.dispose();
    _input.dispose();
    _scroll.dispose();
    unawaited(_voiceService.stop());
    unawaited(_goalEventSubscription?.cancel());
    unawaited(_taskEventSubscription?.cancel());
    super.dispose();
  }

  void _addSI(String text, {String emotion = 'balanced'}) {
    _safeSetState(
      () => _messages.add(
        SIConsoleMessage(text: text, isUser: false, emotion: emotion),
      ),
    );
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
                  'These controls improve readability and spoken guidance.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '1. Type a prompt, then send',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '2. Summary for a quick recap',
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

    _safeSetState(
      () => _messages.add(SIConsoleMessage(text: text, isUser: true)),
    );
    _scrollToBottom();
    _safeSetState(() => _typing = true);

    _dispatchQuery(text);
  }

  bool _handleLocalCommand(String text) {
    final String normalized = text.trim().toLowerCase();
    final String command = normalized.split(RegExp(r'\s+')).first;
    final SIConsoleScreenModel? consoleModel = ref
        .read(siConsoleScreenModelProvider)
        .asData
        ?.value;
    final SIStateAggregation? aggregation = consoleModel?.aggregation;

    if (normalized == '/help' || normalized == 'help') {
      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(
            text:
                'SI Console guide\n\n'
                'SI Console reads signals across your tasks, goals, habits, notes, milestones, timeline, momentum, values, and future trajectory systems.\n\n'
                'Use signal channels when you want a focused readout:\n\n'
                'ANALYZE\n'
                '/tasks — active task pressure, next actions, and execution risks\n'
                '/goals — goal alignment, drift, and strategic priority\n'
                '/milestones — checkpoint health, risk, and next target\n'
                '/values — values alignment and neglected value signals\n\n'
                '/identity — current-vs-future identity alignment and direction\n\n'
                'FUTURE\n'
                '/trajectory — current direction, pressure, and likely outcome\n'
                '/momentum — momentum score, trend, recovery, and forecast\n'
                '/timelinefuture — projected future timeline\n'
                '/paths — alternative future paths\n'
                '/roadmap — future checkpoints and next strategic target\n\n'
                'AUTONOMY\n'
                '/daily — autonomous daily directive\n'
                '/weekly — autonomous weekly directive\n'
                '/focus — recommended focus block\n'
                '/review — review signal and tomorrow adjustment\n'
                '/optimize — life optimization state\n\n'
                'SYSTEM\n'
                '/status — cross-system synchronization and execution state\n'
                '/help — guide and command surface\n\n'
                'Operating rules:\n'
                '- SI Console analyzes and guides.\n'
                '- Creator creates tasks, goals, habits, and notes.\n'
                '- SI Console should explain why a move matters, not just list data.\n\n'
                '${SIConsolePromptCopy.helpSection()}',
            isUser: false,
            emotion: 'focused',
          ),
        );
      });
      _scrollToBottom();
      return true;
    }

    if (normalized == '/weekly' || normalized == 'weekly') {
      final weekly = ref.read(autonomousWeeklyPlannerProvider);
      final momentum = ref.read(momentumEngineProvider);
      final List<String> evidence = <String>[
        'Weekly theme is ${weekly.theme}.',
        'Primary directive is ${weekly.primaryDirective}.',
        'Momentum trend is ${momentum.trend} at ${momentum.score}%.',
      ];

      final String response = SIResponseFrame.build(
        signal:
            'Weekly execution direction is anchored to ${weekly.primaryDirective}.',
        whyItMatters:
            'This matters because weekly focus quality determines whether daily effort compounds or fragments.',
        evidence: evidence,
        tradeoff:
            'Narrow weekly focus improves completion reliability, but it can reduce flexibility for side opportunities.',
        recommendedMove:
            'Commit this week to one primary directive and protect execution blocks around it.',
        confidenceSignal: SIResponseFrame.signalBandFromPercent(momentum.score),
      );

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: response, isUser: false, emotion: 'focused'),
        );
      });

      _scrollToBottom();
      return true;
    }

    if (normalized == '/daily' || normalized == 'daily') {
      final daily = ref.read(autonomousDailyPlannerProvider);
      final momentum = ref.read(momentumEngineProvider);
      final String topDirective = daily.directives.isEmpty
          ? daily.focus
          : daily.directives.first.title;
      final List<String> evidence = <String>[
        'Daily focus is ${daily.focus}.',
        'Top directive is $topDirective.',
        'Pressure is ${momentum.pressurePercent}% and energy is ${momentum.energyPercent}%.',
      ];

      final String response = SIResponseFrame.build(
        signal: 'Daily directive load is centered on ${daily.focus}.',
        whyItMatters:
            'This matters because today\'s execution pattern directly influences tomorrow\'s momentum stability.',
        evidence: evidence,
        tradeoff:
            'Pushing all directives may increase output now, but overload risk rises if pressure stays elevated.',
        recommendedMove:
            'Execute the top directive first, then reassess pressure before adding secondary work.',
        confidenceSignal: SIResponseFrame.signalBandFromPercent(momentum.score),
      );

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: response, isUser: false, emotion: 'focused'),
        );
      });

      _scrollToBottom();
      return true;
    }

    if (normalized == '/focus' || normalized == 'focus') {
      final focusBlock = ref.read(autonomousFocusSchedulerProvider);
      final momentum = ref.read(momentumEngineProvider);
      final List<String> evidence = <String>[
        'Recommended block is ${focusBlock.title}.',
        'Intensity is ${focusBlock.intensity.name} for ${focusBlock.durationMinutes} minutes.',
        'Momentum ${momentum.score}% with pressure ${momentum.pressurePercent}%.',
      ];

      final String response = SIResponseFrame.build(
        signal:
            'Focus scheduling recommends a ${focusBlock.intensity.name} execution block.',
        whyItMatters:
            'This matters because focus block calibration protects momentum without triggering avoidable fatigue.',
        evidence: evidence,
        tradeoff:
            'A deeper block can accelerate progress, but the wrong intensity can increase pressure and reduce consistency.',
        recommendedMove:
            'Run ${focusBlock.durationMinutes} minutes on ${focusBlock.title}, then decide whether to extend or recover.',
        confidenceSignal: SIResponseFrame.signalBandFromPercent(momentum.score),
      );

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: response, isUser: false, emotion: 'focused'),
        );
      });

      _scrollToBottom();
      return true;
    }

    if (normalized == '/review' || normalized == 'review') {
      final review = ref.read(autonomousReviewProvider);
      final momentum = ref.read(momentumEngineProvider);
      final List<String> evidence = <String>[
        'Review score is ${review.score}%.',
        'Alignment signal: ${review.alignment}.',
        'Momentum trend is ${momentum.trend}.',
      ];

      final String response = SIResponseFrame.build(
        signal: 'Review signals ${review.summary.toLowerCase()}',
        whyItMatters:
            'This matters because your next-day setup should be driven by execution quality, not intention alone.',
        evidence: evidence,
        tradeoff:
            'Ignoring adjustment preserves comfort now, but drift risk compounds across consecutive days.',
        recommendedMove: review.tomorrowAdjustment,
        confidenceSignal: SIResponseFrame.signalBandFromPercent(review.score),
      );

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: response, isUser: false, emotion: 'focused'),
        );
      });

      _scrollToBottom();
      return true;
    }

    if (normalized == '/optimize' || normalized == 'optimize') {
      final optimization = ref.read(autonomousLifeOptimizationProvider);
      final momentum = ref.read(momentumEngineProvider);
      final List<String> evidence = <String>[
        'Optimization score is ${optimization.optimizationScore}%.',
        'Primary adjustment is ${optimization.primaryAdjustment}.',
        'Momentum score is ${momentum.score}% with trend ${momentum.trend}.',
      ];

      final String response = SIResponseFrame.build(
        signal:
            'Optimization state points to ${optimization.primaryAdjustment} as the highest-leverage adjustment.',
        whyItMatters:
            'This matters because system-level optimization determines whether effort converts into repeatable progress.',
        evidence: evidence,
        tradeoff:
            'Maintaining current mode preserves routine, but unresolved structural drag can suppress future gains.',
        recommendedMove: optimization.nextDirective,
        confidenceSignal: SIResponseFrame.signalBandFromPercent(
          optimization.optimizationScore,
        ),
      );

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: response, isUser: false, emotion: 'focused'),
        );
      });

      _scrollToBottom();
      return true;
    }

    if (normalized == '/status' || normalized == 'status') {
      final momentum = ref.read(momentumEngineProvider);
      final String status = (aggregation == null)
          ? 'INTELLIGENCE STATUS\n\n'
                'Model is still initializing. Retry /status in a second.\n'
            'If this persists, use /tasks or /trajectory to warm providers.'
          : SIResponseFrame.build(
              signal:
                  'System synchronization is active with momentum at ${momentum.score}% (${momentum.trend}).',
              whyItMatters:
                  'This matters because decision reliability depends on both state freshness and cross-system coherence.',
              evidence: <String>[
                'Tasks ${aggregation.tasks.length}, goals ${aggregation.goals.length}, timeline ${aggregation.timeline.length}.',
                'Milestones ${ref.read(milestonesProvider).asData?.value.length ?? 0}, memories ${aggregation.memories.length}.',
                'Pressure ${aggregation.trajectory.pressureIndex}, divergence ${aggregation.trajectory.behaviorDivergence}%, energy ${momentum.energyPercent}%.',
              ],
              tradeoff:
                  'Broad context gives stronger strategic reads, but weak or sparse surfaces reduce precision in edge cases.',
              recommendedMove:
                  'Use /trajectory for direction, /momentum for execution state, then /daily for immediate action sequencing.',
              confidenceSignal: SIResponseFrame.signalBandFromPercent(
                momentum.score,
              ),
            );

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: status, isUser: false, emotion: 'focused'),
        );
      });
      _scrollToBottom();
      return true;
    }

    if (normalized == '/why' ||
        normalized == 'why' ||
        normalized == 'why this action') {
      final explainable = ref.read(explainableSIProvider);
      final String reasons = explainable.reasons
          .map((reason) => '- ${reason.label}: ${reason.detail}')
          .join('\n');

      final String response =
          'WHY THIS ACTION?\n\n'
          '${explainable.primaryReason}\n\n'
          'Signals:\n$reasons\n\n'
          'Recommended Move:\n${explainable.recommendation}\n\n'
          '${SIConsolePromptCopy.prompt('give me the next move and explain the risk')}';

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: response, isUser: false, emotion: 'focused'),
        );
      });
      _scrollToBottom();
      return true;
    }
    if (normalized == '/simulate' ||
        normalized == 'simulate' ||
        normalized == '/futures' ||
        normalized == 'futures' ||
        normalized == 'what if') {
      final simulations = ref.read(trajectorySimulationProvider);

      final String futures = simulations
          .map(
            (result) =>
                '- ${result.title}: momentum ${result.projectedMomentum}%, pressure ${result.projectedPressure}%, recovery ${result.projectedRecovery}\n  ${result.projectedOutcome}',
          )
          .join('\n\n');

      final String response =
          'TRAJECTORY SIMULATION\n\n'
          'Alternate futures generated from current momentum, pressure, recovery, and trajectory signals.\n\n'
          '$futures\n\n'
          '${SIConsolePromptCopy.prompt('which future should I choose and what is the next action?')}';

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: response, isUser: false, emotion: 'focused'),
        );
      });
      _scrollToBottom();
      return true;
    }
    if (normalized == '/success' || normalized == 'success') {
      final forecast = ref.read(goalSuccessProbabilityProvider);
      final momentum = ref.read(momentumEngineProvider);

      final String confidenceSignal = SIResponseFrame.signalBandFromPercent(
        forecast.probability,
      );

      final response = SIResponseFrame.build(
        signal: 'Goal completion signal is currently $confidenceSignal.',
        whyItMatters:
            'This matters because execution momentum only compounds when goal direction remains viable.',
        evidence: <String>[
          forecast.summary,
          'Momentum trend is ${momentum.trend} at ${momentum.score}%.',
        ],
        tradeoff:
            'Committing to current direction preserves momentum, but unresolved blockers can still reduce completion reliability.',
        recommendedMove: forecast.recommendation,
        confidenceSignal:
            '$confidenceSignal based on current momentum and goal state signals.',
      );

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: response, isUser: false, emotion: 'focused'),
        );
      });

      _scrollToBottom();
      return true;
    }
    if (normalized == '/risk' || normalized == 'risk') {
      final riskState = ref.read(predictiveRiskProvider);
      final momentum = ref.read(momentumEngineProvider);

      final risks = riskState.risks
          .map(
            (risk) =>
                '- ${risk.title}\n'
                '  ${risk.summary}\n'
                '  Mitigation: ${risk.mitigation}',
          )
          .join('\n\n');

      final response = SIResponseFrame.build(
        signal: 'Predictive risk pressure is active across current execution.',
        whyItMatters:
            'The risk signal matters because pressure can silently degrade trajectory quality before output visibly drops.',
        evidence: <String>[
          'Momentum trend is ${momentum.trend} with pressure ${momentum.pressurePercent}%.',
          '${riskState.risks.length} risk lanes flagged by the risk engine.',
          risks,
        ],
        tradeoff:
            'Aggressive execution can increase short-term throughput, but unresolved risk raises the chance of momentum collapse.',
        recommendedMove:
            'Apply the top mitigation first, then re-evaluate momentum before adding new commitments.',
        confidenceSignal: SIResponseFrame.signalBandFromPercent(momentum.score),
      );

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: response, isUser: false, emotion: 'focused'),
        );
      });

      _scrollToBottom();
      return true;
    }
    if (normalized == '/lessons' ||
        normalized == 'lessons' ||
        normalized == '/patterns' ||
        normalized == 'patterns') {
      final memoryIntel = ref.read(memoryIntelligenceProvider);
      final momentum = ref.read(momentumEngineProvider);

      final response = SIResponseFrame.build(
        signal: 'Memory intelligence shows repeat patterns in your execution loop.',
        whyItMatters:
            'This matters because recurring friction compounds faster than isolated mistakes when momentum is under load.',
        evidence: <String>[
          'Recurring win: ${memoryIntel.recurringWin}',
          'Recurring friction: ${memoryIntel.recurringFriction}',
          'Momentum trend is ${momentum.trend}.',
        ],
        tradeoff:
            'Ignoring pattern friction preserves short-term speed, but increases long-term drift and rework.',
        recommendedMove: memoryIntel.focusSuggestion,
        confidenceSignal: 'Signal is moderate from recurring historical patterns.',
      );

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: response, isUser: false, emotion: 'focused'),
        );
      });

      _scrollToBottom();
      return true;
    }
    if (normalized == '/future' ||
        normalized == 'future' ||
        normalized == '/future self' ||
        normalized == 'future self simulation') {
      final simulations = ref.read(futureSelfSimulatorProvider);
      final momentum = ref.read(momentumEngineProvider);

      final String paths = simulations
          .map(
            (path) =>
                '- ${path.name} (${path.days} days)\n'
                '  Outcome: ${path.outcome}\n'
                '  Identity Shift: ${path.identityShift}\n'
                '  ${path.description}',
          )
          .join('\n\n');

      final String response = SIResponseFrame.build(
        signal: 'Future simulations show multiple viable identity trajectories.',
        whyItMatters:
            'This matters because current execution momentum determines which future path becomes dominant.',
        evidence: <String>[
          'Generated ${simulations.length} future path simulations.',
          'Momentum trend is ${momentum.trend} at ${momentum.score}%.',
          paths,
        ],
        tradeoff:
            'A single-lane focus accelerates one outcome, but reduces optionality if conditions change.',
        recommendedMove:
            'Choose one primary path for execution and preserve one smaller exploratory action.',
        confidenceSignal: SIResponseFrame.signalBandFromPercent(momentum.score),
      );

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: response, isUser: false, emotion: 'focused'),
        );
      });

      _scrollToBottom();
      return true;
    }

    if (normalized == '/identity' ||
        normalized == 'identity' ||
        normalized == '/alignment' ||
        normalized == 'alignment' ||
        normalized == '/direction' ||
        normalized == 'direction' ||
        normalized == 'identity drift') {
      final drift = ref.read(identityDriftProvider);
      final momentum = ref.read(momentumEngineProvider);

      final String response = SIResponseFrame.build(
        signal: 'Identity alignment is ${drift.alignment.name} with ${drift.score}% score.',
        whyItMatters:
            'This matters because strategic consistency depends on alignment between current behavior and future direction.',
        evidence: <String>[
          drift.summary,
          'Momentum trend is ${momentum.trend}.',
          'Correction signal: ${drift.correction}',
        ],
        tradeoff:
            'Staying misaligned can preserve immediate comfort, but increases long-term direction drift.',
        recommendedMove:
            'Apply the correction signal to your next execution block today.',
        confidenceSignal: SIResponseFrame.signalBandFromPercent(drift.score),
      );

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(
            text: response,
            isUser: false,
            emotion: drift.score < 50 ? 'cautious' : 'focused',
          ),
        );
      });

      _scrollToBottom();
      return true;
    }

    if (normalized == '/paths' ||
        normalized == 'paths' ||
        normalized == '/lifepaths' ||
        normalized == 'lifepaths') {
      final paths = ref.read(alternativeLifePathsProvider);
      final momentum = ref.read(momentumEngineProvider);
      final trajectory = ref.read(trajectorySummaryProvider);

      final response = SIResponseFrame.build(
      signal:
        'Alternative path signals show multiple strategic lanes, with different risk and flexibility profiles.',
      whyItMatters:
        'This matters because future optionality depends on whether current momentum is concentrated or diversified.',
      evidence: <String>[
        'Momentum trend is ${momentum.trend}.',
        'Trajectory pressure is ${trajectory.pressureIndex}.',
        paths
          .map(
          (p) =>
            '${p.name}: ${p.description} Tradeoff: ${p.tradeoff}',
          )
          .join(' | '),
      ],
      tradeoff:
        'A narrow path can improve completion speed, while broader exploration preserves optionality but slows compounding.',
      recommendedMove:
        'Advance one primary path and schedule one path-opening action this week.',
      confidenceSignal: SIResponseFrame.signalBandFromPercent(momentum.score),
      );

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: response, isUser: false, emotion: 'focused'),
        );
      });

      _scrollToBottom();
      return true;
    }

    if (normalized == '/evolution' ||
        normalized == 'evolution' ||
        normalized == '/whoami' ||
        normalized == 'whoami') {
      final evolution = ref.read(identityEvolutionProvider);

      final response =
          'IDENTITY EVOLUTION\n\n'
          'Stage: ${evolution.stage}\n\n'
          'Trait: ${evolution.trait}\n\n'
          '${evolution.summary}\n\n'
          'Next Evolution:\n${evolution.nextEvolution}';

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: response, isUser: false, emotion: 'focused'),
        );
      });

      _scrollToBottom();
      return true;
    }
    if (normalized == '/timelinefuture' ||
        normalized == 'timelinefuture' ||
        normalized == '/roadmap' ||
        normalized == 'roadmap' ||
        normalized == '/futurepath' ||
        normalized == 'futurepath') {
      final timeline = ref.read(futureTimelineProvider);
      final momentum = ref.read(momentumEngineProvider);
      final trajectory = ref.read(trajectorySummaryProvider);
      final bool roadmapView =
        normalized == '/roadmap' || normalized == 'roadmap';

      final String checkpoints = timeline.checkpoints
          .map(
            (cp) =>
                '- ${cp.label}\n'
                '  ${cp.prediction}',
          )
          .join('\n\n');

      final String response = SIResponseFrame.build(
      signal: roadmapView
        ? 'Roadmap view generated from future timeline signals.'
        : 'Projected timeline sequence shows the next strategic checkpoints.',
      whyItMatters:
        'This matters because future reliability depends on translating long-range direction into near-range checkpoints.',
      evidence: <String>[
        'Timeline model generated ${timeline.checkpoints.length} checkpoints.',
        'Momentum trend is ${momentum.trend} at ${momentum.score}%.',
        'Current pressure index is ${trajectory.pressureIndex}.',
        checkpoints,
      ],
      tradeoff:
        'Checkpoint discipline improves predictability, but overplanning can reduce adaptive response to new signals.',
      recommendedMove: roadmapView
        ? 'Prioritize the nearest checkpoint with one concrete action block this week.'
        : 'Protect the next checkpoint window before adding non-critical work.',
      confidenceSignal: SIResponseFrame.signalBandFromPercent(momentum.score),
      );

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: response, isUser: false, emotion: 'focused'),
        );
      });

      _scrollToBottom();
      return true;
    }

    if (normalized == '/decision' ||
        normalized == 'decision' ||
        normalized == '/future decision' ||
        normalized == 'future decision' ||
        normalized == 'best decision') {
      final decision = ref.read(futureDecisionEngineProvider);
      final momentum = ref.read(momentumEngineProvider);

      final String response = SIResponseFrame.build(
        signal:
            'Future decision engine points to ${decision.recommendedChoice} as the strongest move.',
        whyItMatters:
            'This matters because directional alignment quality determines whether effort compounds or stalls.',
        evidence: <String>[
          'Alignment score is ${decision.alignmentScore}%.',
          decision.reason,
          'Momentum trend is ${momentum.trend}.',
        ],
        tradeoff:
            'Committing early improves decisiveness, but bypassing validation can increase downstream correction cost.',
        recommendedMove:
            'Translate this choice into one concrete task and execute it in the next focus block.',
        confidenceSignal: SIResponseFrame.signalBandFromPercent(
          decision.alignmentScore,
        ),
      );

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: response, isUser: false, emotion: 'focused'),
        );
      });

      _scrollToBottom();
      return true;
    }
    if (normalized == '/twin' ||
        normalized == 'twin' ||
        normalized == 'best version') {
      final twin = ref.read(cognitiveTwinProvider);
      final momentum = ref.read(momentumEngineProvider);

      final response = SIResponseFrame.build(
        signal: 'Cognitive twin mode is ${twin.mode.name}.',
        whyItMatters:
            'This matters because your operating mode changes the type of action that will actually convert into progress.',
        evidence: <String>[
          'Identity statement: ${twin.identityStatement}',
          'Best action: ${twin.bestAction}',
          'Warning signal: ${twin.warning}',
          'Momentum trend is ${momentum.trend}.',
        ],
        tradeoff:
            'Following mode-aware guidance increases precision, but may feel slower than high-intensity forcing when pressure rises.',
        recommendedMove: twin.coachingMessage,
        confidenceSignal: SIResponseFrame.signalBandFromPercent(momentum.score),
      );

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: response, isUser: false, emotion: 'focused'),
        );
      });

      _scrollToBottom();
      return true;
    }
    if (normalized == '/fusion' || normalized == 'fusion') {
      final explainable = ref.read(explainableSIProvider);
      final momentum = ref.read(momentumEngineProvider);

      final String response = SIResponseFrame.build(
        signal: 'Strategic fusion indicates a concentrated next-move signal.',
        whyItMatters:
            'This matters because fused signals reduce noise across modules and improve decision quality.',
        evidence: <String>[
          explainable.primaryReason,
          'Momentum trend is ${momentum.trend}.',
          ...explainable.reasons
              .take(3)
              .map((reason) => '${reason.label}: ${reason.detail}'),
        ],
        tradeoff:
            'Signal fusion improves coherence, but weak source quality can still limit precision.',
        recommendedMove: explainable.recommendation,
        confidenceSignal: SIResponseFrame.signalBandFromPercent(momentum.score),
      );

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: response, isUser: false, emotion: 'focused'),
        );
      });

      _scrollToBottom();
      return true;
    }
    if (normalized == '/replan' ||
        normalized == 'replan' ||
        normalized == '/replan day' ||
        normalized == 'replan day' ||
        normalized == 'replan my day' ||
        normalized == 'missed morning' ||
        normalized == 'overloaded day') {
      final replans = ref.read(adaptiveReplanningProvider);

      final String scenarios = replans.isEmpty
          ? 'No adaptive replanning scenarios are available yet.'
          : replans
                .map(
                  (scenario) =>
                      '- ${scenario.title}\n'
                      '  ${scenario.summary}\n'
                      '  Immediate action: ${scenario.immediateAction}\n'
                      '  Recovery move: ${scenario.recoveryMove}\n'
                      '  Daily adjustment: ${scenario.dailyAdjustment}',
                )
                .join('\n\n');
            final momentum = ref.read(momentumEngineProvider);

            final String response = SIResponseFrame.build(
            signal:
              'Adaptive replanning signals are ${replans.isEmpty ? 'limited' : 'active'} for current execution pressure.',
            whyItMatters:
              'This matters because same-day course correction often prevents multi-day momentum collapse.',
            evidence: <String>[
              'Momentum trend is ${momentum.trend} with pressure ${momentum.pressurePercent}%.',
              scenarios,
            ],
            tradeoff:
              'Replanning reduces trajectory risk, but excessive replanning can create hesitation and execution delay.',
            recommendedMove: replans.isEmpty
              ? 'Run one focused block on the highest-leverage task and reassess after completion.'
              : replans.first.immediateAction,
            confidenceSignal: SIResponseFrame.signalBandFromPercent(momentum.score),
            );

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(text: response, isUser: false, emotion: 'focused'),
        );
      });
      _scrollToBottom();
      return true;
    }
    if (normalized == '/momentum' || normalized == 'momentum') {
      final momentum = ref.read(momentumEngineProvider);
      final String response = SIResponseFrame.build(
        signal:
            'Momentum is ${momentum.trend.toLowerCase()} at ${momentum.score}% with ${momentum.recovery.toLowerCase()} recovery state.',
        whyItMatters:
            'The momentum signal matters because it captures whether current effort is compounding or leaking.',
        evidence: <String>[
          'Energy ${momentum.energyPercent}% and pressure ${momentum.pressurePercent}%.',
          'Completed today: ${momentum.completedToday}.',
          'Forecast: ${momentum.forecast}',
        ],
        tradeoff:
            'Pushing through pressure can boost short-term output, but sustained load can trigger recovery debt.',
        recommendedMove: momentum.isDeclining
            ? 'Stabilize with one clear completion before opening new work.'
            : 'Use current momentum to complete one high-leverage task now.',
        confidenceSignal: SIResponseFrame.signalBandFromPercent(momentum.score),
      );

      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(
            text: response,
            isUser: false,
            emotion: momentum.isDeclining ? 'cautious' : 'focused',
          ),
        );
      });
      _scrollToBottom();
      return true;
    }

    if (command == '/tasks' ||
        command == '/goals' ||
        command == '/milestones' ||
        command == '/values' ||
        command == '/identity' ||
        command == '/plan' ||
        command == '/timeline' ||
        command == '/trajectory') {
      final bool compareIdentity =
          normalized.startsWith('/identity compare') ||
          normalized.startsWith('identity compare');
      final String response = _localSurfaceSummary(command, aggregation);
      _safeSetState(() {
        _messages.add(SIConsoleMessage(text: text, isUser: true));
        _messages.add(
          SIConsoleMessage(
            text: compareIdentity
                ? _localIdentityCompareSummary(aggregation)
                : response,
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

    final momentum = ref.read(momentumEngineProvider);

    switch (command) {
      case '/tasks':
        final List<String> top = aggregation.tasks
            .take(3)
            .map((t) => t.title)
            .toList(growable: false);
        return SIResponseFrame.build(
          signal:
              'Task pressure is ${aggregation.tasks.isEmpty ? 'minimal' : 'active'} with ${aggregation.tasks.length} active tasks.',
          whyItMatters:
              'This matters because task load without execution focus creates fragmentation before momentum visibly drops.',
          evidence: <String>[
            'Top active tasks: ${top.isEmpty ? 'none available' : top.join(' | ')}',
            'Momentum trend is ${momentum.trend} at ${momentum.score}%.',
            'Future pressure index is ${aggregation.trajectory.pressureIndex}.',
          ],
          tradeoff:
              'Keeping many tasks open preserves optionality, but reduces decisive execution throughput.',
          recommendedMove:
              'Execute one highest-leverage task now and defer lower-impact items until completion is logged.',
          confidenceSignal: SIResponseFrame.signalBandFromPercent(momentum.score),
        );
      case '/goals':
        final List<String> top = aggregation.goals
            .take(3)
            .map((g) => g.title)
            .toList(growable: false);
        return SIResponseFrame.build(
          signal:
              'Goal direction is ${aggregation.signals.goalDrift ? 'showing drift' : 'currently stable'} across ${aggregation.goals.length} goals.',
          whyItMatters:
              'This matters because goals only compound when execution and trajectory stay aligned over time.',
          evidence: <String>[
            'Top goals: ${top.isEmpty ? 'none available' : top.join(' | ')}',
            'Behavior divergence is ${aggregation.trajectory.behaviorDivergence}%.',
            'Task avoidance signal: ${aggregation.signals.taskAvoidance ? 'active' : 'not dominant'}.',
          ],
          tradeoff:
              'Holding many concurrent goals can preserve ambition, but weakens execution density on priority outcomes.',
          recommendedMove:
              'Prioritize one goal for the next execution block and delay non-critical goal moves today.',
          confidenceSignal: SIResponseFrame.signalBandFromPercent(momentum.score),
        );
      case '/plan':
        final String blocks = aggregation.planPreview.isEmpty
            ? 'No adaptive blocks generated yet.'
            : aggregation.planPreview.take(3).map((b) => '- $b').join('\n');
        return SIResponseFrame.build(
          signal:
              'Plan pressure is ${aggregation.planPreview.isEmpty ? 'uncertain' : 'visible'} from current adaptive blocks.',
          whyItMatters:
              'This matters because plan structure determines whether momentum is protected or leaked through context switching.',
          evidence: <String>[
            'Plan preview block count: ${aggregation.planPreview.length}.',
            'Upcoming blocks: $blocks',
            'Pressure index: ${aggregation.trajectory.pressureIndex}.',
          ],
          tradeoff:
              'Dense scheduling increases perceived progress, but can amplify execution drag under high pressure.',
          recommendedMove:
              'Keep only the highest-leverage block fixed and re-sequence the rest after first completion.',
          confidenceSignal: SIResponseFrame.signalBandFromPercent(momentum.score),
        );
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
        return SIResponseFrame.build(
          signal:
              'Milestone health is ${summary.healthScore}% with ${summary.overdue} overdue checkpoints.',
          whyItMatters:
              'This matters because checkpoint quality is the bridge between strategic goals and daily execution reality.',
          evidence: <String>[
            'Active ${summary.active}, completed ${summary.completed}, upcoming ${summary.upcoming}.',
            'Top risk: ${risks.isEmpty ? 'none flagged' : '${risks.first.milestone.title} - ${risks.first.reason}'}',
            'Top milestones: ${topMilestones.isEmpty ? 'none available' : topMilestones.join(' | ')}',
            'Closest checkpoint: ${summary.closestMilestone?.title ?? 'none'}; next: ${summary.nextMilestone?.title ?? 'none'}.',
            'Overdue list: ${overdue.take(2).map((MilestoneEntity m) => m.title).join(' | ').trim().isEmpty ? 'none' : overdue.take(2).map((MilestoneEntity m) => m.title).join(' | ')}',
            'Upcoming list: ${upcoming.take(2).map((MilestoneEntity m) => m.title).join(' | ').trim().isEmpty ? 'none' : upcoming.take(2).map((MilestoneEntity m) => m.title).join(' | ')}',
          ],
          tradeoff:
              'Driving only near checkpoints increases short-term closure, but can hide drift in deeper milestones.',
          recommendedMove:
              'Recover the highest-risk overdue checkpoint first, then protect the next milestone window.',
          confidenceSignal: SIResponseFrame.signalBandFromPercent(
            summary.healthScore,
          ),
        );
      case '/values':
        final CoreValuesAlignment values = ref.read(
          coreValuesAlignmentProvider,
        );
        final List<String> rows = CoreValueType.values
            .map(
              (CoreValueType value) =>
                  '${coreValueTitle(value)}: ${values.scores[value]?.score ?? 0}%',
            )
            .toList(growable: false);
        return SIResponseFrame.build(
          signal:
              'Values alignment is ${values.overall}% with strongest signal in ${coreValueTitle(values.strongest)}.',
          whyItMatters:
              'This matters because values drift degrades strategic trust even when task output appears healthy.',
          evidence: <String>[
            rows.join(' | '),
            'Most neglected value is ${coreValueTitle(values.mostNeglected)}.',
            'Goal drift signal is ${aggregation.signals.goalDrift ? 'active' : 'not dominant'}.',
          ],
          tradeoff:
              'Over-optimizing for output can improve speed now, but it increases identity mismatch if neglected values persist.',
          recommendedMove:
              values.recommendations.firstWhere(
                (String line) =>
                    line.toLowerCase().contains('schedule one action'),
                orElse: () =>
                    'Schedule one action this week aligned to your neglected value.',
              ),
          confidenceSignal: SIResponseFrame.signalBandFromPercent(
            values.overall,
          ),
        );
      case '/identity':
        final SoulMapAlignment soulMap = ref.read(soulMapAlignmentProvider);
        final int purpose =
            soulMap.scores[SoulMapDimension.purpose]?.score ?? 0;
        final int identity =
            soulMap.scores[SoulMapDimension.identity]?.score ?? 0;
        final int values =
            soulMap.scores[SoulMapDimension.coreValues]?.score ?? 0;
        final int futureSelf =
            soulMap.scores[SoulMapDimension.futureSelf]?.score ?? 0;
        final String strongest = soulMapDimensionTitle(soulMap.strongest);
        final String weakest = soulMapDimensionTitle(soulMap.weakest);
        final String action = soulMap.recommendations.firstWhere(
          (String line) =>
              line.toLowerCase().contains('schedule one concrete action'),
          orElse: () =>
              'Schedule one concrete action this week to strengthen $weakest.',
        );
        final int identityScore = ((purpose + identity + values + futureSelf) /
            4)
          .round();
        return SIResponseFrame.build(
          signal:
            'Identity direction signal is mixed with strongest area in $strongest and weakest in $weakest.',
          whyItMatters:
            'This matters because identity alignment determines whether future trajectory feels coherent or conflicted.',
          evidence: <String>[
          'Purpose $purpose%, identity $identity%, values $values%, future self $futureSelf%.',
          'Momentum trend is ${momentum.trend}.',
          'Task avoidance signal is ${aggregation.signals.taskAvoidance ? 'active' : 'not dominant'}.',
          ],
          tradeoff:
            'Leaning only on strengths preserves confidence, but unresolved weak dimensions can slow long-term evolution.',
          recommendedMove:
            '$action Use /identity compare to inspect current-vs-future direction gap.',
          confidenceSignal: SIResponseFrame.signalBandFromPercent(identityScore),
        );
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
        return SIResponseFrame.build(
          signal:
              'Timeline health is $healthScore% with $overdueCount overdue items and risk score $riskScore%.',
          whyItMatters:
              'This matters because timeline pressure reveals delivery friction earlier than end-state outcomes.',
          evidence: <String>[
            'Events ${aggregation.timeline.length}, upcoming $upcomingCount, risk events $riskEventsCount.',
            'Recommendations active: $recommendationCount.',
            'Next deadline: $nextDeadline.',
            'Recent events: ${events.isEmpty ? 'none available' : events.join(' | ')}',
          ],
          tradeoff:
              'Ignoring timeline friction can protect short-term comfort, but increases future compression and miss risk.',
          recommendedMove:
              'Recover one overdue item or protect the next deadline block before adding new scope.',
          confidenceSignal: SIResponseFrame.signalBandFromPercent(healthScore),
        );
      case '/trajectory':
        final int momentumPercent =
            (aggregation.trajectory.momentum * 100).round();
        return SIResponseFrame.build(
          signal:
              'Future trajectory is ${aggregation.trajectory.pressureIndex >= 70 ? 'under pressure' : 'currently stable'} with momentum at $momentumPercent%.',
          whyItMatters:
              'This matters because trajectory quality reflects whether today\'s behavior supports tomorrow\'s outcomes.',
          evidence: <String>[
            'Pressure ${aggregation.trajectory.pressureIndex}, divergence ${aggregation.trajectory.behaviorDivergence}%.',
            'Momentum engine trend: ${momentum.trend} (${momentum.score}%).',
            'Alert signal: ${aggregation.trajectory.alert}',
            'Goals active: ${aggregation.goals.length}; milestones active: ${ref.read(milestonesProvider).asData?.value.length ?? 0}.',
          ],
          tradeoff:
              'Short-term acceleration can increase immediate progress, but unmanaged pressure raises drift and recovery cost.',
          recommendedMove:
              'Protect one high-leverage execution block and remove one low-impact commitment today.',
          confidenceSignal: SIResponseFrame.signalBandFromPercent(momentum.score),
        );
      default:
        return 'Module command not recognized.';
    }
  }

  String _localIdentityCompareSummary(SIStateAggregation? aggregation) {
    if (aggregation == null) {
      return 'SI is still loading module data. Retry the command in a second.';
    }

    final SoulMapFutureSelfComparison compare = ref.read(
      soulMapFutureSelfComparisonProvider,
    );
    return SIResponseFrame.build(
      signal:
          'Current-vs-future identity gap is ${compare.gap}% with stance ${compare.stance}.',
      whyItMatters:
          'This matters because unresolved gap increases strategic drift even when daily execution appears active.',
      evidence: <String>[
        'Current alignment: ${compare.currentSelfAlignment}%.',
        'Future readiness: ${compare.futureSelfReadiness}%.',
        'Gap recommendation: ${compare.recommendation}',
      ],
      tradeoff:
          'Maintaining current mode preserves familiarity, but can delay identity convergence and long-range consistency.',
      recommendedMove:
          'Apply the gap recommendation to the next high-leverage action today.',
      confidenceSignal: SIResponseFrame.signalBandFromPercent(
        compare.currentSelfAlignment,
      ),
    );
  }

  Future<void> _dispatchQuery(String text) async {
    try {
      final recommendation = await ref
          .read(aiControllerProvider)
          .sendMessage(text);
      if (!mounted) return;
      final String message = recommendation?.message.trim() ?? '';
      if (message.isEmpty || SIConsoleResponseValidator.isInvalid(message)) {
        _safeSetState(() {
          _typing = false;
          _messages.add(
            const SIConsoleMessage(
              text:
                  'No grounded intelligence response was generated. Ask with a specific signal and intent, for example: "show trajectory pressure", "summarize drifting goals", or "what should I execute next".',
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
          SIConsoleMessage(
            text: message,
            isUser: false,
            emotion: recommendation?.emotion ?? 'balanced',
          ),
        );
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      _safeSetState(() {
        _typing = false;
        _messages.add(
          const SIConsoleMessage(
            text:
                'Full intelligence context lock failed for that request. Retry, or target a signal channel directly: tasks, goals, milestones, values, identity, timeline, or trajectory.',
            isUser: false,
            emotion: 'cautious',
          ),
        );
      });
      _scrollToBottom();
    }
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
    final executionSignals = ref.watch(executionSignalsProvider);
    final int executionStabilityPercent =
        (executionSignals.completionStability7d * 100).round();
    final consoleModelAsync = ref.watch(siConsoleScreenModelProvider);
    final SIConsoleScreenModel? consoleModel = consoleModelAsync.asData?.value;
    final Object? consoleError = consoleModelAsync.asError?.error;
    final String? engineSnapshot = consoleModel?.engineSnapshot;
    final String? integrationSnapshot = consoleModel?.integrationSnapshot;
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
                    ref.read(appFlowProvider.notifier).toNexus();
                  },
                  engineSnapshot: engineSnapshot,
                  seededQueryCount: seededQueryCount,
                  onSpeakSummary: () {
                    final List<SIConsoleMessage> recentAssistant = _messages
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
                  executionCompletedToday: executionSignals.completedToday,
                  executionDeferralsToday:
                      executionSignals.skippedToday +
                      executionSignals.delayedToday,
                  executionStabilityPercent: executionStabilityPercent,
                  integrationSnapshot: integrationSnapshot,
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
                            : Column(
                                children: [
                                  if (consoleError != null)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        6,
                                        14,
                                        0,
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.fromLTRB(
                                          10,
                                          8,
                                          10,
                                          8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2A1620),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.redAccent.withValues(
                                              alpha: 0.35,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'SI context is limited right now.',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  SizedBox(height: 3),
                                                  Text(
                                                    'Some intelligence data could not refresh.',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 10,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            TextButton(
                                              onPressed: () {
                                                ref.invalidate(
                                                  siConsoleScreenModelProvider,
                                                );
                                              },
                                              child: const Text('Retry'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: ListView.builder(
                                      controller: _scroll,
                                      padding: EdgeInsets.fromLTRB(
                                        14,
                                        consoleError != null ? 6 : 6,
                                        14,
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
                                        return _BubbleTile(msg: _messages[i]);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: composerBottomInset),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: composerMaxHeight,
                            ),
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
    required this.executionCompletedToday,
    required this.executionDeferralsToday,
    required this.executionStabilityPercent,
    this.integrationSnapshot,
    this.engineSnapshot,
  });
  final VoidCallback onBack;
  final int seededQueryCount;
  final VoidCallback onSpeakSummary;
  final VoidCallback onSpeakAccessibility;
  final int executionCompletedToday;
  final int executionDeferralsToday;
  final int executionStabilityPercent;
  final String? integrationSnapshot;
  final String? engineSnapshot;

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 760;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                child: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white54,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    seededQueryCount > 0
                        ? 'SI CONSOLE QRY:$seededQueryCount'
                        : 'STRATEGIC INTELLIGENCE',
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
                'SYNCED',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 2,
                  color: Colors.greenAccent,
                ),
              ),
            ],
          ),
          if (engineSnapshot != null) ...[
            const SizedBox(height: 3),
            Text(
              engineSnapshot ?? '',
              style: const TextStyle(
                fontSize: 8,
                letterSpacing: 1,
                color: Colors.white54,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (integrationSnapshot != null) ...[
            const SizedBox(height: 1),
            Text(
              integrationSnapshot ?? '',
              style: const TextStyle(
                fontSize: 8,
                letterSpacing: 1,
                color: Colors.white38,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: <Widget>[
              _ExecutionPill(
                label: 'DONE',
                value: '$executionCompletedToday',
                color: const Color(0xFF7AF7C4),
              ),
              _ExecutionPill(
                label: 'DEFERS',
                value: '$executionDeferralsToday',
                color: const Color(0xFFFFB86B),
              ),
              _ExecutionPill(
                label: 'STABILITY',
                value: '$executionStabilityPercent%',
                color: AppColors.neonViolet,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              GestureDetector(
                onTap: onSpeakSummary,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 7,
                    vertical: 2,
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
                        size: 10,
                        color: AppColors.neonCyan,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'RECAP',
                        style: TextStyle(
                          fontSize: 7,
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
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 5 : 6,
                    vertical: 2,
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
                        size: 10,
                        color: Colors.white70,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'A11Y',
                        style: TextStyle(
                          fontSize: 7,
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

class _ExecutionPill extends StatelessWidget {
  const _ExecutionPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 7,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message bubble
// ---------------------------------------------------------------------------

class _BubbleTile extends ConsumerWidget {
  const _BubbleTile({required this.msg});
  final SIConsoleMessage msg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isUser = msg.isUser;
    final String? emotion = msg.emotion;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _SIAvatar(emotion: msg.emotion),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
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
                          fontSize: 12,
                          height: 1.45,
                          color: isUser ? Colors.white70 : Colors.white,
                          fontFamily: isUser ? null : 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isUser) ...[
                  const SizedBox(height: 3),
                  GestureDetector(
                    onTap: () => unawaited(
                      ref.read(voiceServiceProvider).speak(msg.text),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.neonCyan.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.neonCyan.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.volume_up_rounded,
                            color: AppColors.neonCyan,
                            size: 11,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'SPEAK',
                            style: TextStyle(
                              color: AppColors.neonCyan,
                              fontSize: 8,
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
      width: 24,
      height: 24,
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
            fontSize: 7,
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
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(
        emotion.toUpperCase(),
        style: TextStyle(
          fontSize: 7,
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _SIAvatar(),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    this.compact = false,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool compact;

  void _insertCommand(String command) {
    controller
      ..text = '$command '
      ..selection = TextSelection.collapsed(offset: command.length + 1);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool forceCompact =
            constraints.hasBoundedHeight && constraints.maxHeight < 150;
        final bool effectiveCompact = compact || forceCompact;

        return Container(
          padding: EdgeInsets.fromLTRB(
            14,
            effectiveCompact ? 7 : 9,
            14,
            effectiveCompact ? 8 : 12,
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
                    'Signal channels',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: SIConsoleCommands.values
                          .map(
                            (command) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () {
                                  _insertCommand(command);
                                  onSend();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
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
                                    command,
                                    style: const TextStyle(
                                      color: AppColors.neonCyan,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2.4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                  const SizedBox(height: 6),
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
                          fontSize: 13,
                        ),
                        cursorColor: AppColors.neonCyan,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Ask about your future direction...',
                          hintStyle: const TextStyle(
                            color: Colors.white24,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0A1520),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
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
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onSend,
                      child: Container(
                        width: 40,
                        height: 40,
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
                          size: 16,
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
