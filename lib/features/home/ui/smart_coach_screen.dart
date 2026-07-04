import 'dart:async';

import 'package:fantastic_guacamole/core/constants/app_assets.dart';
import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/errors/error_boundary_widget.dart';
import 'package:fantastic_guacamole/core/utils/crisis_guard.dart';
import 'package:fantastic_guacamole/core/widgets/smart_pressable.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/features/emotion/emotion_provider.dart';
import 'package:fantastic_guacamole/features/emotion/emotional_state.dart';
import 'package:fantastic_guacamole/features/emotion/widgets/emotion_selector.dart';
import 'package:fantastic_guacamole/features/progression/widgets/progress_bar.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/task_view.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/holo_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SmartCoachScreen extends ConsumerStatefulWidget {
  const SmartCoachScreen({super.key});

  @override
  ConsumerState<SmartCoachScreen> createState() => _SmartCoachScreenState();
}

class _SmartCoachScreenState extends ConsumerState<SmartCoachScreen> {
  double _energy = 0.7;
  EmotionalState _emotion = EmotionalState.neutral;
  final _notesController = TextEditingController();
  final _followUpController = TextEditingController();
  final ScrollController _scroll = ScrollController();

  String? _coachingMessage;
  final List<_Exchange> _followUps = [];
  bool _saved = false;
  bool _gettingCoaching = false;

  @override
  void initState() {
    super.initState();
    _energy = ref.read(siStateProvider).energy;
    _emotion = ref.read(emotionProvider);
  }

  @override
  void dispose() {
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

    if (isCrisis(notes) && mounted) {
      await showCrisisDialog(context);
      return;
    }

    setState(() => _gettingCoaching = true);

    // Persist reflection
    final currentSi = ref.read(siStateProvider);
    ref
        .read(siStateProvider.notifier)
        .replaceState(
          energy: _energy,
          fatigue: _fatigueFromEmotion(_emotion, currentSi.fatigue),
          completedToday: currentSi.completedToday,
        );
    ref.read(emotionProvider.notifier).set(_emotion);

    if (notes.isNotEmpty) {
      await ref
          .read(workspaceStoreServiceProvider)
          .appendSiReflection(
            note: notes,
            energy: _energy,
            emotion: _emotion.name,
          );
    }

    if (!mounted) return;

    final String message = _buildCoachingMessage(_energy, _emotion, notes);
    setState(() {
      _coachingMessage = message;
      _saved = true;
      _gettingCoaching = false;
    });

    // Award XP for reflecting + checking in
    ref.read(profileProvider.notifier).addXP(10);

    // Speak the coaching message
    unawaited(ref.read(voiceServiceProvider).speak(message));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendFollowUp() {
    final String text = _followUpController.text.trim();
    if (text.isEmpty) return;
    if (isCrisis(text)) {
      showCrisisDialog(context);
      return;
    }
    _followUpController.clear();
    final String reply = _buildFollowUpReply(text, _energy, _emotion);
    setState(() => _followUps.add(_Exchange(question: text, answer: reply)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgHome,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 4),
                    const _DisclaimerText(),
                    const SizedBox(height: 12),
                    const _NextStepCard(),
                    const SizedBox(height: 12),
                    const _ProgressionBanner(),
                    const SizedBox(height: 12),
                    const _QuickNavRow(),
                    const SizedBox(height: 8),
                    const _QuickAddButton(),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 14),
                    _CoachPanel(
                      label: 'EMOTIONAL STATE',
                      accentColor: AppColors.neonViolet,
                      child: EmotionSelector(
                        selected: _emotion,
                        onSelect: (e) => setState(() {
                          _emotion = e;
                          _saved = false;
                        }),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _CoachPanel(
                      label: "WHAT'S ON YOUR MIND?",
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
                              'Share your thoughts, struggles, or what you\'re working through...',
                          hintStyle: TextStyle(color: Colors.white24),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() => _saved = false),
                      ),
                    ),
                    const SizedBox(height: 20),
                    HoloButton(
                      label: _gettingCoaching
                          ? 'THINKING...'
                          : (_saved ? 'REFRESH COACHING' : 'GET COACHING'),
                      color: AppColors.neonCyan,
                      onTap: _gettingCoaching ? () {} : _getCoaching,
                    ),
                    if (_coachingMessage != null) ...[
                      const SizedBox(height: 20),
                      _CoachPanel(
                        label: "COACH'S INSIGHT",
                        accentColor: AppColors.memoryAmber,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _coachingMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.7,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _VoiceButton(message: _coachingMessage!),
                                const SizedBox(width: 10),
                                const _MicButton(),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._followUps.map(
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
              if (_coachingMessage != null)
                _FollowUpBar(
                  controller: _followUpController,
                  onSend: _sendFollowUp,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        SmartPressable(
          onTap: () => ref.read(appFlowProvider.notifier).toCoach(),
          child: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white54,
            size: 18,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.neonCyan, AppColors.neonViolet],
              ).createShader(bounds),
              child: const Text(
                'SMART COACH',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                  color: Colors.white,
                ),
              ),
            ),
            const Text(
              'LIFE INTELLIGENCE',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bubble(String text, {required bool isUser}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
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

  static double _fatigueFromEmotion(EmotionalState emotion, double current) {
    switch (emotion) {
      case EmotionalState.fatigued:
        return 0.75;
      case EmotionalState.anxious:
        return 0.65;
      case EmotionalState.scattered:
        return 0.60;
      case EmotionalState.negative:
        return 0.55;
      case EmotionalState.neutral:
        return current;
      case EmotionalState.calm:
        return 0.25;
      case EmotionalState.positive:
        return 0.30;
      case EmotionalState.focused:
        return 0.20;
      case EmotionalState.energized:
        return 0.15;
    }
  }

  static String _buildCoachingMessage(
    double energy,
    EmotionalState emotion,
    String notes,
  ) {
    final int pct = (energy * 100).round();

    final String opening = energy > 0.65
        ? 'You\'re running strong at $pct% — that\'s real capacity to work with.'
        : energy < 0.4
        ? 'At $pct% energy, your body is sending a clear message. Honor it.'
        : 'Steady at $pct%. Consistency built here is what lasts.';

    final String insight;
    switch (emotion) {
      case EmotionalState.energized:
        insight =
            'You\'re energized — use this for something that truly matters to you, not just what\'s urgent. Bold decisions made in peak states stick.';
      case EmotionalState.focused:
        insight =
            'Your focus is sharp. Point it at the thing you\'ve been avoiding — that\'s usually where the most growth hides.';
      case EmotionalState.positive:
        insight =
            'Positivity compounds. Let it flow outward — encourage someone, start something creative, or strengthen a relationship you\'ve neglected.';
      case EmotionalState.calm:
        insight =
            'Calm is clarity. From here, you can see your life honestly. Are you building toward the future you actually want, or drifting?';
      case EmotionalState.neutral:
        insight =
            'Neutral days are the foundation. No one sees the reps you put in here, but you feel them. Steady work is still work.';
      case EmotionalState.scattered:
        insight =
            'When the mind scatters, simplify. Pick one thing — not ten, one. Completion restores clarity faster than anything else.';
      case EmotionalState.anxious:
        insight =
            'Anxiety often means you care deeply about something. Breathe, name what you\'re afraid of. A fear named loses half its power.';
      case EmotionalState.negative:
        insight =
            'Hard states are data, not verdicts. What is this feeling pointing toward? Discomfort is sometimes a compass, not an enemy.';
      case EmotionalState.fatigued:
        insight =
            'Recovery is not weakness — it\'s strategy. Your best work requires your best self. Rest today so you can show up fully tomorrow.';
    }

    final String closing = notes.isEmpty
        ? 'What\'s the most honest thing you could do for yourself right now?'
        : 'You wrote: "${notes.length > 80 ? '${notes.substring(0, 80)}...' : notes}" — sit with that. There\'s something important in it.';

    return '$opening\n\n$insight\n\n$closing';
  }

  static String _buildFollowUpReply(
    String question,
    double energy,
    EmotionalState emotion,
  ) {
    final String q = question.toLowerCase();
    if (q.contains('how') && (q.contains('start') || q.contains('begin'))) {
      return 'Start small, start now. The smallest honest action toward your intention is enough. Momentum follows movement, not the other way around.';
    }
    if (q.contains('afraid') || q.contains('fear') || q.contains('scared')) {
      return 'Fear is information, not instruction. What is it protecting you from, and is that protection still serving you? Often the answer is no.';
    }
    if (q.contains('motivat')) {
      return 'Motivation follows action — not the other way around. You don\'t wait to feel ready. You act, and readiness appears.';
    }
    if (q.contains('routine') || q.contains('habit')) {
      return 'Systems beat willpower every time. Build an environment where the right behavior is the easiest choice, and discipline becomes unnecessary.';
    }
    if (q.contains('purpose') || q.contains('meaning') || q.contains('why')) {
      return 'Purpose isn\'t found — it\'s built through what you repeatedly choose. What are you already choosing? That is your life\'s direction.';
    }
    if (q.contains('fail') || q.contains('mistake') || q.contains('wrong')) {
      return 'Failure is the fastest feedback loop available to you. Every person you admire has a longer list of failures than successes. The difference is they kept going.';
    }
    if (q.contains('stress') || q.contains('overwhelm')) {
      return 'When overwhelmed, your only job is to reduce the list. What are you doing that doesn\'t need to be done? Remove that first.';
    }
    return 'That\'s worth sitting with. The fact that you\'re asking the question means part of you already knows the answer — trust that.';
  }
}

class _Exchange {
  const _Exchange({required this.question, required this.answer});
  final String question;
  final String answer;
}

class _FollowUpBar extends StatelessWidget {
  const _FollowUpBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xCC0B111C),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Ask a follow-up...',
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
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded),
              color: AppColors.neonCyan,
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

class _MicButton extends ConsumerWidget {
  const _MicButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VoiceState voice = ref.watch(voiceControllerProvider);
    final bool listening = voice.isListening;
    return GestureDetector(
      onTap: () {
        if (listening) {
          ref.read(voiceControllerProvider.notifier).stopListening();
        } else {
          ref.read(voiceControllerProvider.notifier).startListening();
        }
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

// ─── Next step card ───────────────────────────────────────────────────────────

class _NextStepCard extends ConsumerWidget {
  const _NextStepCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String text = ref.watch(nextActionTextProvider);
    final tasks = ref.watch(tasksProvider).asData?.value;
    final momentum = ref.watch(momentumProvider);

    return SmartPressable(
      onTap: () {
        if (tasks != null && tasks.isNotEmpty) {
          final sorted = [...tasks]
            ..sort((a, b) => a.priority.compareTo(b.priority));
          ref
              .read(focusTaskProvider.notifier)
              .set(TaskView.fromTask(sorted.first));
        }
        ref.read(focusControllerProvider.notifier).start();
        ref.read(appFlowProvider.notifier).toFocus();
      },
      pressedScale: 0.97,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.neonCyan.withValues(alpha: 0.10),
              AppColors.neonViolet.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.30)),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonCyan.withValues(alpha: 0.10),
              blurRadius: 24,
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
                    color: AppColors.neonCyan,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'NEXT STEP',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2.5,
                    color: AppColors.neonCyan,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            if (momentum.active) ...[
              const SizedBox(height: 6),
              Text(
                'MOMENTUM  ×${momentum.chainCount}',
                style: TextStyle(
                  color: AppColors.memoryAmber.withValues(alpha: 0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '+10 XP when complete',
                  style: TextStyle(
                    color: AppColors.memoryAmber,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'START NOW  →',
                  style: TextStyle(
                    color: AppColors.neonCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Progression banner ───────────────────────────────────────────────────────

class _ProgressionBanner extends ConsumerWidget {
  const _ProgressionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressionProvider).progress;
    final int pct = (progress.levelProgress * 100).round();

    return SmartPressable(
      onTap: () => ref.read(appFlowProvider.notifier).toProgression(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF050D1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.memoryAmber.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.memoryAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.memoryAmber.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'LVL ${progress.level}',
                style: const TextStyle(
                  color: AppColors.memoryAmber,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        '$pct% to Level ${progress.level + 1}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${progress.xpToNext} XP',
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ProgressBar(
                    value: progress.levelProgress,
                    color: AppColors.memoryAmber,
                    height: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.deepOrangeAccent,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  '${progress.streak}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick nav row ───────────────────────────────────────────────────────────

class _QuickNavRow extends ConsumerWidget {
  const _QuickNavRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        _QuickNavCard(
          label: 'GOALS',
          icon: Icons.flag_rounded,
          color: AppColors.memoryAmber,
          onTap: () => ref.read(appFlowProvider.notifier).toGoals(),
        ),
        const SizedBox(width: 8),
        _QuickNavCard(
          label: 'MEMORIES',
          icon: Icons.auto_awesome_rounded,
          color: AppColors.neonViolet,
          onTap: () => ref.read(appFlowProvider.notifier).toMemories(),
        ),
        const SizedBox(width: 8),
        _QuickNavCard(
          label: 'SOUL MAP',
          icon: Icons.hub_rounded,
          color: AppColors.neonCyan,
          onTap: () => ref.read(appFlowProvider.notifier).toSoulMap(),
        ),
      ],
    );
  }
}

class _QuickNavCard extends StatelessWidget {
  const _QuickNavCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Disclaimer ───────────────────────────────────────────────────────────────

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

// ─── Quick add button ─────────────────────────────────────────────────────────

class _QuickAddButton extends ConsumerWidget {
  const _QuickAddButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showQuickAdd(context, ref),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.neonCyan.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.25)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: AppColors.neonCyan, size: 16),
            SizedBox(width: 6),
            Text(
              'ADD TASK',
              style: TextStyle(
                color: AppColors.neonCyan,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickAdd(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B111C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'QUICK ADD TASK',
              style: TextStyle(
                color: AppColors.neonCyan,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Task title...',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF1A2440),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _submit(ctx, ref, ctrl),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _submit(ctx, ref, ctrl),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'ADD',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(
    BuildContext ctx,
    WidgetRef ref,
    TextEditingController ctrl,
  ) async {
    final String title = ctrl.text.trim();
    if (title.isEmpty) return;
    Navigator.of(ctx).pop();
    final task = TaskEntity(
      id: 't_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      createdAt: DateTime.now(),
    );
    await ref.read(domainTaskRepositoryProvider).saveTask(task);
    ref.invalidate(tasksProvider);
  }
}
