import 'dart:async';

import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/features/emotion/widgets/emotion_selector.dart';
import 'package:fantastic_guacamole/features/progression/widgets/progress_bar.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_provider.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_target_registry.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/crisis_dialog.dart';
import 'package:fantastic_guacamole/ui/widgets/error_boundary_widget.dart';
import 'package:fantastic_guacamole/ui/widgets/holo_button.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
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
  late final Future<void> Function(String) _speakVoice;
  late final Future<void> Function() _stopVoice;
  final _notesController = TextEditingController();
  final _followUpController = TextEditingController();
  final ScrollController _scroll = ScrollController();

  String? _coachingMessage;
  String? _coachingPrompt;
  String? _lastSavedNotes;
  String? _followUpError;
  final List<_Exchange> _followUps = [];
  bool _saved = false;
  bool _gettingCoaching = false;
  bool _sendingFollowUp = false;

  List<_Exchange> get _visibleFollowUps {
    const int maxVisibleFollowUps = 20;
    if (_followUps.length <= maxVisibleFollowUps) {
      return _followUps;
    }
    return _followUps.sublist(_followUps.length - maxVisibleFollowUps);
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

    setState(() => _gettingCoaching = true);

    final CoachCoachingResult result = await coach.requestCoaching(
      energy: _energy,
      emotion: _emotion,
      notes: notes,
      history: _conversationHistory(),
      previousSavedNotes: _lastSavedNotes,
    );
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
      final String reply = await coach.requestFollowUp(
        input: text,
        energy: _energy,
        emotion: _emotion,
        reflection: _notesController.text.trim(),
        history: _conversationHistory(),
      );
      if (!mounted) return;
      setState(() {
        _followUps.add(_Exchange(question: text, answer: reply));
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
    final List<Map<String, String>> history = <Map<String, String>>[];
    final String initialPrompt = _coachingPrompt?.trim() ?? '';
    final String initialResponse = _coachingMessage?.trim() ?? '';
    if (initialPrompt.isNotEmpty) {
      history.add(<String, String>{'role': 'user', 'content': initialPrompt});
    }
    if (initialResponse.isNotEmpty) {
      history.add(<String, String>{'role': 'assistant', 'content': initialResponse});
    }
    for (final _Exchange exchange in _followUps) {
      history
        ..add(<String, String>{'role': 'user', 'content': exchange.question})
        ..add(<String, String>{'role': 'assistant', 'content': exchange.answer});
    }
    return history.length > 8 ? history.sublist(history.length - 8) : history;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(extendedDomainBootstrapProvider);
    final smartModel = ref.watch(smartCoachScreenModelProvider).asData?.value;
    final String modelCoachMessage = smartModel?.decision.coachMessage ?? '';
    final String effectiveCoachMessage = (_coachingMessage?.trim().isNotEmpty ?? false)
        ? _coachingMessage!
        : (modelCoachMessage.trim().isNotEmpty
              ? modelCoachMessage
              : 'Stabilize scope and execute one focused action now.');
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
                  padding: EdgeInsets.fromLTRB(20, 20, 20, hasCoachMessage ? 20 : 12),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 4),
                    const _DisclaimerText(),
                    const SizedBox(height: 12),
                    const _ProgressionBanner(),
                    const SizedBox(height: 12),
                    const _QuickNavRow(),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.read(appFlowProvider.notifier).toCreator(),
                      child: const Text('OPEN CREATOR TO MAKE TASK'),
                    ),
                    const SizedBox(height: 14),
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
                      label: 'FOCUS CONTEXT',
                      accentColor: AppColors.neonViolet,
                      child: TextField(
                        controller: _notesController,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6),
                        decoration: const InputDecoration(
                          hintText: 'Share your current context, friction, or desired outcome...',
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
                      const SizedBox(height: 20),
                      _CoachPanel(
                        label: 'SMART INSIGHT',
                        accentColor: AppColors.memoryAmber,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              effectiveCoachMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.7,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _VoiceButton(message: effectiveCoachMessage),
                                _VoiceSummaryButton(
                                  headline: effectiveCoachMessage,
                                  energy: _energy,
                                  emotion: _emotion,
                                ),
                                const _VoiceAccessibilityButton(),
                                const _MicButton(),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._visibleFollowUps.map(
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

  Widget _buildHeader() {
    return Row(
      children: [
        SmartPressable(
          onTap: () => ref.read(appFlowProvider.notifier).toCoach(),
          child: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 18),
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
              'ADAPTIVE LIFE LOGIC',
              style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white38),
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
}

class _Exchange {
  const _Exchange({required this.question, required this.answer});
  final String question;
  final String answer;
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
        '• One topic: lose weight, tired, stressed, sleep, nutrition, exercise, productivity, goals\n'
        '• One feeling: drained, anxious, stuck, unmotivated\n'
        '• One detail: sleep, food, deadlines, workouts, or what keeps failing\n\n'
        'Examples: “I’m tired”, “lose weight”, “stressed about work”, “what should I do next?”',
        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
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
                    const Icon(Icons.error_outline, color: AppColors.recallRed, size: 14),
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
                    TextButton(onPressed: sending ? null : onSend, child: const Text('Retry')),
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
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFF1A2440),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
  const _CoachPanel({required this.label, required this.child, required this.accentColor});

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
          BoxShadow(color: accentColor.withValues(alpha: 0.06), blurRadius: 20, spreadRadius: -2),
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
  const _EnergySlider({required this.value, required this.color, required this.onChanged});

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
              style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5),
            ),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
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
          border: Border.all(color: AppColors.memoryAmber.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.volume_up_rounded, color: AppColors.memoryAmber, size: 15),
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
  const _VoiceSummaryButton({required this.headline, required this.energy, required this.emotion});

  final String headline;
  final double energy;
  final EmotionalState emotion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => unawaited(
        ref
            .read(voiceServiceProvider)
            .speakSummary(
              title: 'Smart Coach voice summary',
              points: <String>[
                'Energy is ${(energy * 100).round()} percent',
                'Emotion state is ${emotion.name}',
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
              'SUMMARY',
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
      onTap: () => unawaited(
        ref
            .read(voiceServiceProvider)
            .speakAccessibilityHint(
              surface: 'Smart Coach',
              controls: const <String>[
                'Adjust energy slider to set intensity',
                'Select emotional state to tune guidance',
                'Use get insight to generate coaching',
                'Use speak button to read the latest insight aloud',
                'Use summary button for condensed voice recap',
                'Use microphone button for voice interactions',
              ],
            ),
      ),
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
            Icon(Icons.accessibility_new_rounded, color: Colors.white70, size: 15),
            SizedBox(width: 5),
            Text(
              'A11Y',
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
            color: listening ? AppColors.neonCyan.withValues(alpha: 0.6) : Colors.white24,
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

// ─── Progression banner ───────────────────────────────────────────────────────

class _ProgressionBanner extends ConsumerWidget {
  const _ProgressionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressionProvider).progress;
    final int pct = (progress.levelProgress * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.memoryAmber.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.memoryAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.memoryAmber.withValues(alpha: 0.4)),
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
                      style: const TextStyle(color: Colors.white24, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ProgressBar(value: progress.levelProgress, color: AppColors.memoryAmber, height: 4),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.local_fire_department, color: Colors.deepOrangeAccent, size: 14),
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
      style: TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 0.3, height: 1.4),
    );
  }
}
