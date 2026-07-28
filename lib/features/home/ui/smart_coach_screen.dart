import 'package:fantastic_guacamole/state/providers/goal_success_probability_provider.dart';
import 'package:fantastic_guacamole/state/providers/predictive_risk_provider.dart';
import 'package:fantastic_guacamole/state/providers/memory_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/cognitive_twin_provider.dart';
import 'package:fantastic_guacamole/state/providers/life_os_provider.dart';
import 'package:fantastic_guacamole/state/providers/memory_graph_provider.dart';
import 'dart:async';
import 'package:fantastic_guacamole/state/providers/adaptive_replanning_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_daily_planner_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_focus_scheduler_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_goal_restructure_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_life_optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_mission_control_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_review_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_command_briefing_provider.dart';
import 'package:fantastic_guacamole/state/providers/explainable_si_provider.dart';
import 'package:fantastic_guacamole/state/providers/voice_command_provider.dart';
import 'package:fantastic_guacamole/state/providers/voice_command_handoff_provider.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/features/emotion/widgets/emotion_selector.dart';

import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_provider.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_target_registry.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/crisis_dialog.dart';
import 'package:fantastic_guacamole/ui/widgets/error_boundary_widget.dart';
import 'package:fantastic_guacamole/ui/widgets/holo_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fantastic_guacamole/features/home/ui/widgets/smart_coach_hero.dart';
import 'package:fantastic_guacamole/features/home/ui/models/smart_coach_exchange.dart';

import 'package:fantastic_guacamole/features/home/ui/models/smart_coach_conversation_state.dart';

class SmartCoachScreen extends ConsumerStatefulWidget {
  const SmartCoachScreen({super.key});

  @override
  ConsumerState<SmartCoachScreen> createState() => _SmartCoachScreenState();
}

class _SmartCoachScreenState extends ConsumerState<SmartCoachScreen> {
  double _energy = 0.7;
  EmotionalState _emotion = EmotionalState.neutral;
  late final Future<void> Function(String) _speakVoice;
  late final Future<void> Function() _stopVoice;
  final _notesController = TextEditingController();
  final _followUpController = TextEditingController();
  final ScrollController _scroll = ScrollController();

  String? _coachingMessage;
  String? _coachingPrompt;
  String? _lastSavedNotes;
  String? _followUpError;
  final List<SmartCoachExchange> _followUps = [];
  bool _saved = false;
  bool _gettingCoaching = false;
  bool _sendingFollowUp = false;

  Future<void> _logEmotionCheckIn({
    required EmotionalState emotion,
    required double energy,
    required String notes,
  }) async {
    final String energyLabel = '${(energy * 100).round()}%';
    final String trimmedNotes = notes.trim();
    final String detail = trimmedNotes.isEmpty
        ? 'State: ${emotion.name}. Energy: $energyLabel.'
        : 'State: ${emotion.name}. Energy: $energyLabel. Context: $trimmedNotes';

    await ref
        .read(timelineActionsProvider)
        .addEmotion(
          title: 'Smart Planner emotional check-in',
          detail: detail,
          relatedId: 'smart_coach',
        );
  }

  @override
  void initState() {
    super.initState();
    AppAnalytics.track('coach_opened');
    final voiceService = ref.read(voiceServiceProvider);
    _speakVoice = voiceService.speak;
    _stopVoice = voiceService.stop;
    _energy = ref.read(siStateProvider).energy;
    _emotion = ref.read(emotionProvider);
  }

  @override
  void dispose() {
    unawaited(_stopVoice());
    _notesController.dispose();
    _followUpController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _getCoaching() async {
    if (_gettingCoaching) return;
    try {
      await _doGetCoaching();
    } catch (e, s) {
      if (mounted) {
        setState(() => _gettingCoaching = false);
        ErrorBoundary.of(context)?.captureError(e, s);
      }
    }
  }

  Future<void> _doGetCoaching() async {
    final String notes = _notesController.text.trim();
    final CoachQueryController coach = ref.read(coachQueryControllerProvider);

    AppAnalytics.track(
      'smart_coach_requested',
      params: <String, Object?>{'has_notes': notes.isNotEmpty},
    );

    if (coach.detectsCrisis(notes) && mounted) {
      await showCrisisDialog(context);
      return;
    }

    unawaited(
      _logEmotionCheckIn(emotion: _emotion, energy: _energy, notes: notes),
    );

    setState(() => _gettingCoaching = true);

    final CoachCoachingResult result;
    try {
      result = await coach
          .requestCoaching(
            energy: _energy,
            emotion: _emotion,
            notes: notes,
            history: _conversationHistory(),
            previousSavedNotes: _lastSavedNotes,
          )
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _gettingCoaching = false;
        _coachingPrompt = notes.isEmpty ? 'quick check-in' : notes;
        _coachingMessage =
            'Insight request timed out. Tap GET INSIGHT again or shorten your input for a faster response.';
      });
      return;
    }
    if (!mounted) return;

    setState(() {
      _coachingPrompt = result.prompt;
      _coachingMessage = result.message;
      _lastSavedNotes = result.savedNotes;
      _saved = true;
      _gettingCoaching = false;
    });

    AppAnalytics.track(
      'smart_coach_response_rendered',
      params: <String, Object?>{'message_length': result.message.length},
    );

    // Speak the coaching message
    unawaited(_speakVoice(result.message));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendFollowUp() async {
    if (_sendingFollowUp) return;
    final String text = _followUpController.text.trim();
    if (text.isEmpty) return;
    final CoachQueryController coach = ref.read(coachQueryControllerProvider);

    AppAnalytics.track(
      'smart_coach_followup_requested',
      params: <String, Object?>{'input_length': text.length},
    );

    if (coach.detectsCrisis(text)) {
      if (!mounted) return;
      await showCrisisDialog(context);
      return;
    }
    _followUpController.clear();
    setState(() {
      _sendingFollowUp = true;
      _followUpError = null;
    });
    try {
      final String reply = await coach
          .requestFollowUp(
            input: text,
            energy: _energy,
            emotion: _emotion,
            reflection: _notesController.text.trim(),
            history: _conversationHistory(),
          )
          .timeout(const Duration(seconds: 25));
      if (!mounted) return;
      setState(() {
        _followUps.add(SmartCoachExchange(question: text, answer: reply));
        _sendingFollowUp = false;
      });
      AppAnalytics.track(
        'smart_coach_followup_response_rendered',
        params: <String, Object?>{'reply_length': reply.length},
      );
      unawaited(_speakVoice(reply));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _sendingFollowUp = false;
        _followUpError = 'Follow-up timed out. Retry with a shorter prompt.';
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _sendingFollowUp = false;
        _followUpError = 'Follow-up transmit failed. Tap Retry Link.';
      });
      ErrorBoundary.of(context)?.captureError(error, stackTrace);
    }
  }

  List<Map<String, String>> _conversationHistory() {
    return SmartCoachConversationState(
      coachingMessage: _coachingMessage,
      coachingPrompt: _coachingPrompt,
      followUpError: _followUpError,
      followUps: _followUps,
    ).toHistory();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(extendedDomainBootstrapProvider);
    final briefing = ref.watch(dailyCommandBriefingProvider);
    final explainable = ref.watch(explainableSIProvider);
    final adaptiveReplans = ref.watch(adaptiveReplanningProvider);
    final memoryIntel = ref.watch(memoryIntelligenceProvider);
    final twin = ref.watch(cognitiveTwinProvider);
    final lifeOs = ref.watch(lifeOSProvider);
    final memoryGraph = ref.watch(memoryGraphProvider);
    final missionControl = ref.watch(autonomousMissionControlProvider);
    final dailyPlan = ref.watch(autonomousDailyPlannerProvider);
    final focusBlock = ref.watch(autonomousFocusSchedulerProvider);
    final goalRestructure = ref.watch(autonomousGoalRestructureProvider);
    final review = ref.watch(autonomousReviewProvider);
    final optimization = ref.watch(autonomousLifeOptimizationProvider);
    final predictiveRisk = ref.watch(predictiveRiskProvider);
    final goalForecast = ref.watch(goalSuccessProbabilityProvider);
    final AsyncValue<SmartCoachScreenModel> smartModelAsync = ref.watch(
      smartCoachScreenModelProvider,
    );
    final smartModel = smartModelAsync.asData?.value;
    final SISourceHealth? sourceHealth = smartModel?.aggregation.sourceHealth;
    final bool sourceDegraded =
        sourceHealth?.tasks == SISourceStatus.error ||
        sourceHealth?.insights == SISourceStatus.error;
    final bool siUnavailable = smartModelAsync.hasError || sourceDegraded;
    final String modelCoachMessage = smartModel?.decision.coachMessage ?? '';
    final String modelNextAction = smartModel?.decision.nextAction ?? '';
    final List<Task> suggestedTasks =
        smartModel?.aggregation.tasks ?? const <Task>[];

    final String effectiveCoachMessage =
        (_coachingMessage?.trim().isNotEmpty ?? false)
        ? _coachingMessage!
        : (modelCoachMessage.trim().isNotEmpty
              ? modelCoachMessage
              : siUnavailable
              ? 'SI recommendation unavailable right now. Retry sync or create one task manually.'
              : 'No active recommendation yet. Capture one task or tap GET INSIGHT.');
    final bool hasCoachMessage = effectiveCoachMessage.trim().isNotEmpty;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgHome,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    hasCoachMessage ? 20 : 12,
                  ),
                  children: [
                    SmartCoachHero(
                      coachMessage: effectiveCoachMessage,
                      nextAction: modelNextAction,
                      taskCount: suggestedTasks.length,
                      coachOnline: !siUnavailable,
                    ),
                    const SizedBox(height: 4),
                    const _DisclaimerText(),
                    const SizedBox(height: 8),

                    const SizedBox(height: 8),
                    _CoachSyncStatus(
                      modelAsync: smartModelAsync,
                      sourceHealth: sourceHealth,
                    ),
                    const SizedBox(height: 12),

                    const SizedBox(height: 10),
                    _CoachPanel(
                      label: 'ENERGY',
                      accentColor: AppColors.neonCyan,
                      child: _EnergySlider(
                        value: _energy,
                        color: AppColors.neonCyan,
                        onChanged: (v) => setState(() {
                          _energy = v;
                          _saved = false;
                        }),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _CoachPanel(
                      label: 'EMOTIONAL STATE',
                      accentColor: AppColors.neonViolet,
                      child: EmotionSelector(
                        selected: _emotion,
                        onSelect: (e) {
                          if (_emotion == e) {
                            return;
                          }
                          setState(() {
                            _emotion = e;
                            _saved = false;
                          });
                          ref.read(emotionProvider.notifier).set(e);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    _CoachPanel(
                      label: 'FOCUS CONTEXT',
                      accentColor: AppColors.neonViolet,
                      child: TextField(
                        controller: _notesController,
                        maxLines: 4,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.6,
                        ),
                        decoration: const InputDecoration(
                          hintText:
                              'Share your current context, friction, or desired outcome...',
                          hintStyle: TextStyle(color: Colors.white24),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) {
                          if (_saved) {
                            setState(() => _saved = false);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _InsightCheatSheet(),
                    const SizedBox(height: 10),
                    _AdaptiveReplanningPanel(scenarios: adaptiveReplans),
                    const SizedBox(height: 10),
                    _MemoryPatternsPanel(memoryIntel: memoryIntel),
                    const SizedBox(height: 10),
                    _RiskForecastPanel(riskState: predictiveRisk),
                    const SizedBox(height: 10),
                    _CognitiveTwinPanel(twin: twin),
                    const SizedBox(height: 10),
                    _LifeOSPanel(lifeOs: lifeOs),
                    const SizedBox(height: 10),
                    _AutonomousExecutionBrief(
                      missionControl: missionControl,
                      dailyPlan: dailyPlan,
                      focusBlock: focusBlock,
                      goalRestructure: goalRestructure,
                      review: review,
                      optimization: optimization,
                    ),
                    const SizedBox(height: 10),
                    _MemoryGraphPanel(memoryGraph: memoryGraph),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('GOAL SUCCESS FORECAST'),
                          const SizedBox(height: 6),
                          const Text('%'),
                          Text(goalForecast.summary),
                          Text(goalForecast.recommendation),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TutorialTarget(
                      id: 'home.start_focus_button',
                      child: HoloButton(
                        label: _gettingCoaching
                            ? 'THINKING...'
                            : (_saved ? 'REFRESH INSIGHT' : 'GET INSIGHT'),
                        color: AppColors.neonCyan,
                        onTap: _gettingCoaching
                            ? () {}
                            : () {
                                ref
                                    .read(tutorialControllerProvider)
                                    .reportEvent('tap:home.start_focus_button');
                                _getCoaching();
                              },
                      ),
                    ),
                    if (hasCoachMessage) ...[
                      const SizedBox(height: 16),
                      _CoachPanel(
                        label: 'SMART INSIGHT',
                        accentColor: AppColors.memoryAmber,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // existing coach message
                            Text(effectiveCoachMessage),

                            // <-- INSERT HERE
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.neonCyan.withValues(
                                  alpha: 0.06,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.neonCyan.withValues(
                                    alpha: 0.20,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'WHY THIS ACTION?',
                                    style: TextStyle(
                                      color: AppColors.neonCyan,
                                      fontSize: 10,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    explainable.primaryReason,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...explainable.reasons.map(
                                    (reason) => Padding(
                                      padding: const EdgeInsets.only(bottom: 5),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${reason.label}: ',
                                            style: const TextStyle(
                                              color: AppColors.neonCyan,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              reason.detail,
                                              style: const TextStyle(
                                                color: Colors.white60,
                                                fontSize: 12,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Recommended move: ${explainable.recommendation}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      height: 1.4,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _VoiceButton(
                                        message: effectiveCoachMessage,
                                      ),
                                      _VoiceSummaryButton(
                                        headline: effectiveCoachMessage,
                                        energy: _energy,
                                        emotion: _emotion,
                                        briefing: briefing,
                                      ),
                                      const _VoiceAccessibilityButton(),
                                      const _MicButton(),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...SmartCoachConversationState(
                        coachingMessage: _coachingMessage,
                        coachingPrompt: _coachingPrompt,
                        followUpError: _followUpError,
                        followUps: _followUps,
                      ).visibleFollowUps().map(
                        (ex) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _bubble(ex.question, isUser: true),
                              const SizedBox(height: 6),
                              _bubble(ex.answer, isUser: false),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: hasCoachMessage
            ? AnimatedPadding(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: _FollowUpBar(
                  controller: _followUpController,
                  onSend: _sendFollowUp,
                  sending: _sendingFollowUp,
                  errorText: _followUpError,
                ),
              )
            : null,
      ),
    );
  }

  Widget _bubble(String text, {required bool isUser}) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double maxWidth = (screenWidth * 0.78).clamp(220, 420).toDouble();
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.neonViolet.withValues(alpha: 0.18)
              : AppColors.neonCyan.withValues(alpha: 0.10),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
          border: Border.all(
            color: isUser
                ? AppColors.neonViolet.withValues(alpha: 0.35)
                : AppColors.neonCyan.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF9BE7FF),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _InsightCheatSheet extends StatelessWidget {
  const _InsightCheatSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Text(
        'Get Insight cheat sheet:\n'
        '- One topic: lose weight, tired, stressed, sleep, nutrition, exercise, productivity, goals\n'
        '- One feeling: drained, anxious, stuck, unmotivated\n'
        '- One detail: sleep, food, deadlines, workouts, or what keeps failing\n\n'
        "Examples: \"I'm tired\", \"lose weight\", \"stressed about work\", \"what should I do next?\"",
        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
      ),
    );
  }
}

class _AdaptiveReplanningPanel extends StatelessWidget {
  const _AdaptiveReplanningPanel({required this.scenarios});

  final List<AdaptiveReplanningScenario> scenarios;

  @override
  Widget build(BuildContext context) {
    if (scenarios.isEmpty) {
      return const SizedBox.shrink();
    }

    final AdaptiveReplanningScenario scenario = scenarios.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xEE07111F),
            AppColors.memoryAmber.withValues(alpha: 0.10),
            AppColors.neonViolet.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.memoryAmber.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.memoryAmber.withValues(alpha: 0.08),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ADAPTIVE REPLAN',
            style: TextStyle(
              color: AppColors.memoryAmber,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            scenario.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            scenario.immediateAction,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          ...scenario.moves
              .take(3)
              .map(
                (String move) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '- $move',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _AutonomousExecutionBrief extends StatelessWidget {
  const _AutonomousExecutionBrief({
    required this.missionControl,
    required this.dailyPlan,
    required this.focusBlock,
    required this.goalRestructure,
    required this.review,
    required this.optimization,
  });

  final MissionControlState missionControl;
  final AutonomousDailyPlan dailyPlan;
  final AutonomousFocusBlock focusBlock;
  final GoalRestructureRecommendation goalRestructure;
  final AutonomousReviewState review;
  final LifeOptimizationState optimization;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xEE07111F),
            AppColors.neonCyan.withValues(alpha: 0.10),
            AppColors.memoryAmber.withValues(alpha: 0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonCyan.withValues(alpha: 0.08),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AUTONOMOUS EXECUTION BRIEF',
            style: TextStyle(
              color: AppColors.neonCyan,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            missionControl.status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Do now: ${missionControl.primaryAction}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Today Focus: ${dailyPlan.focus}',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Focus: ${focusBlock.title} • ${focusBlock.durationMinutes} min',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Goal adjustment: ${goalRestructure.title}',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Review ${review.score}% • ${review.tomorrowAdjustment}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Optimization ${optimization.optimizationScore}% • ${optimization.nextDirective}',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowUpBar extends StatelessWidget {
  const _FollowUpBar({
    required this.controller,
    required this.onSend,
    required this.sending,
    this.errorText,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xCC0B111C),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.recallRed,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        errorText!,
                        style: const TextStyle(
                          color: AppColors.recallRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: sending ? null : onSend,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !sending,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (!sending) onSend();
                    },
                    decoration: InputDecoration(
                      hintText: 'Send a follow-up question...',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1A2440),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: sending ? 'Sending message' : 'Send message',
                  onPressed: sending ? null : onSend,
                  icon: sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  color: AppColors.neonCyan,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachPanel extends StatelessWidget {
  const _CoachPanel({
    required this.label,
    required this.child,
    required this.accentColor,
  });

  final String label;
  final Widget child;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 2,
                height: 14,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.5,
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _EnergySlider extends StatelessWidget {
  const _EnergySlider({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CURRENT ENERGY',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            activeTrackColor: color,
            inactiveTrackColor: Colors.white12,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}

class _VoiceButton extends ConsumerWidget {
  const _VoiceButton({required this.message});
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => unawaited(ref.read(voiceServiceProvider).speak(message)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.memoryAmber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.memoryAmber.withValues(alpha: 0.4),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.volume_up_rounded,
              color: AppColors.memoryAmber,
              size: 15,
            ),
            SizedBox(width: 6),
            Text(
              'SPEAK',
              style: TextStyle(
                color: AppColors.memoryAmber,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceSummaryButton extends ConsumerWidget {
  const _VoiceSummaryButton({
    required this.headline,
    required this.energy,
    required this.emotion,
    required this.briefing,
  });

  final String headline;
  final double energy;
  final EmotionalState emotion;
  final DailyCommandBriefing briefing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => unawaited(
        ref
            .read(voiceServiceProvider)
            .speakSummary(
              title: 'Daily command briefing',
              points: <String>[
                'Focus: ${briefing.focus}',
                'Momentum: ${briefing.momentum}',
                'Energy: ${briefing.energy}',
                'Recovery: ${briefing.recovery}',
                'Warning: ${briefing.warning}',
                'Coach action: ${briefing.coachAction}',
                'Current emotion state is ${emotion.name}',
                headline,
              ],
            ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.neonCyan.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.45)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.summarize_rounded, color: AppColors.neonCyan, size: 15),
            SizedBox(width: 6),
            Text(
              'BRIEFING',
              style: TextStyle(
                color: AppColors.neonCyan,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceAccessibilityButton extends ConsumerWidget {
  const _VoiceAccessibilityButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet<void>(
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
                      'A11Y means accessibility. Use these controls for easier reading and audio guidance.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.5,
                      ),
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
              .speakAccessibilityHint(
                surface: 'Smart Planner',
                controls: const <String>[
                  'Adjust energy slider to set intensity',
                  'Select emotional state to tune guidance',
                  'Use get insight to generate coaching',
                  'Use speak button to read the latest insight aloud',
                  'Use summary button for condensed voice recap',
                  'Use microphone button for voice interactions',
                ],
              ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.accessibility_new_rounded,
              color: Colors.white70,
              size: 15,
            ),
            SizedBox(width: 5),
            Text(
              'ACCESS',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicButton extends ConsumerWidget {
  const _MicButton();

  void _routeVoiceCommand(WidgetRef ref, String spokenText) {
    final result = ref.read(voiceCommandParserProvider).parse(spokenText);

    if (result.intent == VoiceCommandIntent.createTask ||
        result.intent == VoiceCommandIntent.createGoal ||
        result.intent == VoiceCommandIntent.recordMemory) {
      ref.read(voiceCommandHandoffProvider.notifier).setFromResult(result);
    }

    unawaited(ref.read(voiceServiceProvider).speak(result.confirmation));

    final flow = ref.read(appFlowProvider.notifier);

    switch (result.intent) {
      case VoiceCommandIntent.createTask:
      case VoiceCommandIntent.createGoal:
      case VoiceCommandIntent.recordMemory:
      case VoiceCommandIntent.openCreator:
        flow.toCreator();
        return;
      case VoiceCommandIntent.showTrajectory:
        flow.toTrajectoryEngine();
        return;
      case VoiceCommandIntent.showBriefing:
        flow.toNexus();
        return;
      case VoiceCommandIntent.nextMove:
      case VoiceCommandIntent.replanDay:
      case VoiceCommandIntent.startFocusSession:
      case VoiceCommandIntent.openCoach:
        flow.toSmartCoach();
        return;
      case VoiceCommandIntent.openTimeline:
        flow.toTimeline();
        return;
      case VoiceCommandIntent.openProfile:
        flow.toProfile();
        return;
      case VoiceCommandIntent.openProgression:
        flow.toProgression();
        return;
      case VoiceCommandIntent.openSiConsole:
        flow.toConsole();
        return;
      case VoiceCommandIntent.unknown:
        return;
    }
  }

  String _latestVoiceText(VoiceState voice) {
    final String last = voice.lastResponse.trim();
    if (last.isNotEmpty) {
      return last;
    }
    return voice.recognizedText.trim();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VoiceState voice = ref.watch(voiceControllerProvider);
    final bool listening = voice.isListening;
    return GestureDetector(
      onTap: () async {
        if (listening) {
          await ref.read(voiceControllerProvider.notifier).stopListening();
          final VoiceState latest = ref.read(voiceControllerProvider);
          final String spokenText = _latestVoiceText(latest);

          if (spokenText.isNotEmpty) {
            _routeVoiceCommand(ref, spokenText);
          } else {
            unawaited(
              ref
                  .read(voiceServiceProvider)
                  .speak('No voice command was captured. Try again.'),
            );
          }
          return;
        }

        await ref.read(settingsUiActionsProvider).requestVoicePermission();
        await ref.read(voiceControllerProvider.notifier).startListening();

        if (!context.mounted) {
          return;
        }

        final VoiceState latest = ref.read(voiceControllerProvider);
        final String message =
            latest.error ??
            'Listening. Speak a command, then tap the mic again to route it.';

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: listening
              ? AppColors.neonCyan.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: listening
                ? AppColors.neonCyan.withValues(alpha: 0.6)
                : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              listening ? Icons.mic : Icons.mic_none_rounded,
              color: listening ? AppColors.neonCyan : Colors.white54,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              listening ? 'LISTENING...' : 'SPEAK',
              style: TextStyle(
                color: listening ? AppColors.neonCyan : Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachSyncStatus extends StatelessWidget {
  const _CoachSyncStatus({
    required this.modelAsync,
    required this.sourceHealth,
  });

  final AsyncValue<SmartCoachScreenModel> modelAsync;
  final SISourceHealth? sourceHealth;

  @override
  Widget build(BuildContext context) {
    final bool hasTasksError = sourceHealth?.tasks == SISourceStatus.error;
    final bool hasInsightsError =
        sourceHealth?.insights == SISourceStatus.error;
    final String status = modelAsync.isLoading
        ? 'SYNCING'
        : modelAsync.hasError || hasTasksError || hasInsightsError
        ? 'LIMITED'
        : 'LIVE';
    final Color accent = switch (status) {
      'LIVE' => AppColors.neonCyan,
      'SYNCING' => AppColors.memoryAmber,
      _ => AppColors.recallRed,
    };
    final List<String> issues = <String>[
      if (hasTasksError) 'tasks',
      if (hasInsightsError) 'insights',
      if (modelAsync.hasError) 'model',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Text(
            'COACH LINK: $status',
            style: TextStyle(
              color: accent,
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            issues.isEmpty ? 'all sources ready' : issues.join(', '),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Disclaimer ------------------------------------------------------------

class _DisclaimerText extends StatelessWidget {
  const _DisclaimerText();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'This app is not a substitute for professional mental health care.',
      style: TextStyle(
        color: Colors.white30,
        fontSize: 10,
        letterSpacing: 0.3,
        height: 1.4,
      ),
    );
  }
}

class _MemoryPatternsPanel extends StatelessWidget {
  const _MemoryPatternsPanel({required this.memoryIntel});

  final MemoryIntelligenceState memoryIntel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RECURRING PATTERNS'),
          const SizedBox(height: 8),
          Text('Win: ${memoryIntel.recurringWin}'),
          const SizedBox(height: 4),
          Text('Friction: ${memoryIntel.recurringFriction}'),
          const SizedBox(height: 4),
          Text('Lesson: ${memoryIntel.lesson}'),
          const SizedBox(height: 4),
          Text('Focus: ${memoryIntel.focusSuggestion}'),
        ],
      ),
    );
  }
}

class _RiskForecastPanel extends StatelessWidget {
  const _RiskForecastPanel({required this.riskState});

  final PredictiveRiskState riskState;

  @override
  Widget build(BuildContext context) {
    final topRisk = riskState.risks.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RISK FORECAST'),
          const SizedBox(height: 8),
          Text(topRisk.title),
          const SizedBox(height: 4),
          Text(topRisk.summary),
          const SizedBox(height: 4),
          Text('Mitigation: ${topRisk.mitigation}'),
        ],
      ),
    );
  }
}

class _CognitiveTwinPanel extends StatelessWidget {
  const _CognitiveTwinPanel({required this.twin});

  final CognitiveTwinState twin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xEE07111F),
            AppColors.neonViolet.withValues(alpha: 0.10),
            AppColors.neonCyan.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonViolet.withValues(alpha: 0.08),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COGNITIVE TWIN',
            style: TextStyle(
              color: AppColors.neonViolet,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            twin.identityStatement,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Best action: ${twin.bestAction}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            twin.warning,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _LifeOSPanel extends StatelessWidget {
  const _LifeOSPanel({required this.lifeOs});

  final LifeOSState lifeOs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xEE07111F),
            AppColors.memoryAmber.withValues(alpha: 0.10),
            AppColors.neonCyan.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.memoryAmber.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.memoryAmber.withValues(alpha: 0.08),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIFE OS',
            style: TextStyle(
              color: AppColors.memoryAmber,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lifeOs.mission,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Primary action: ${lifeOs.primaryAction}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Identity stage: ${lifeOs.identityStage}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryGraphPanel extends StatelessWidget {
  const _MemoryGraphPanel({required this.memoryGraph});

  final MemoryGraphState memoryGraph;

  @override
  Widget build(BuildContext context) {
    if (memoryGraph.nodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xEE07111F),
            AppColors.neonViolet.withValues(alpha: 0.10),
            AppColors.memoryAmber.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonViolet.withValues(alpha: 0.08),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MEMORY GRAPH',
            style: TextStyle(
              color: AppColors.neonViolet,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          ...memoryGraph.nodes
              .take(4)
              .map(
                (node) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${node.type.toUpperCase()}: ${node.title} → ${node.connection}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
