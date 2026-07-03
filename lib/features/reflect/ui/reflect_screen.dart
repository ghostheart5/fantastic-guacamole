import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/utils/crisis_guard.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/features/emotion/emotion_provider.dart';
import 'package:fantastic_guacamole/features/emotion/emotional_state.dart';
import 'package:fantastic_guacamole/features/emotion/widgets/emotion_selector.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/holo_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReflectScreen extends ConsumerStatefulWidget {
  const ReflectScreen({super.key});

  @override
  ConsumerState<ReflectScreen> createState() => _ReflectScreenState();
}

class _ReflectScreenState extends ConsumerState<ReflectScreen> {
  double _energy = 0.7;
  EmotionalState _emotion = EmotionalState.neutral;
  final _controller = TextEditingController();
  bool _saved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _emotion = ref.read(emotionProvider);
    _energy = ref.read(siStateProvider).energy;
  }

  Future<void> _saveReflection() async {
    final String note = _controller.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Neural dump is empty. Add a note before saving.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (isCrisis(note) && mounted) {
      await showCrisisDialog(context);
      return;
    }

    if (_saving) return;
    setState(() => _saving = true);

    final currentSi = ref.read(siStateProvider);
    ref
        .read(siStateProvider.notifier)
        .replaceState(
          energy: _energy,
          fatigue: _fatigueFromEmotion(_emotion, currentSi.fatigue),
          completedToday: currentSi.completedToday,
        );
    ref.read(emotionProvider.notifier).set(_emotion);

    await ref
        .read(workspaceStoreServiceProvider)
        .appendSiReflection(
          note: note,
          energy: _energy,
          emotion: _emotion.name,
        );

    if (!mounted) return;

    await ref
        .read(memoriesProvider.notifier)
        .capture(_extractMemory(note, _emotion, _energy));

    if (!mounted) return;

    await ref.read(timelineProvider.notifier).record(TimelineEventEntity(
          id: 'rf_${DateTime.now().millisecondsSinceEpoch}',
          type: TimelineEventType.reflection,
          title: 'Reflection saved',
          detail: note.length > 60 ? '${note.substring(0, 60)}…' : note,
          timestamp: DateTime.now(),
        ));

    if (!mounted) return;

    setState(() {
      _saved = true;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reflection archived. Energy ${(_energy * 100).round()}%, '
          'state ${_emotion.name}.',
        ),
        duration: const Duration(seconds: 2),
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

  static String _extractMemory(
      String note, EmotionalState emotion, double energy) {
    final pct = (energy * 100).round();
    final sentences = note
        .split(RegExp(r'[.!?]+'))
        .where((s) => s.trim().length > 8)
        .toList();
    if (sentences.isNotEmpty) return '${sentences.first.trim()}.';
    return 'Felt ${emotion.name} at $pct% energy.';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      voiceControllerProvider.select((v) => v.recognizedText),
      (_, text) {
        if (text.isNotEmpty) {
          final current = _controller.text;
          _controller.text =
              current.isEmpty ? text : '$current $text';
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
          setState(() => _saved = false);
        }
      },
    );
    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/reflect_bg.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.neonViolet,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonViolet.withValues(alpha: 0.8),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.neonViolet, AppColors.neonCyan],
                          ).createShader(bounds),
                          child: const Text(
                            'REFLECT',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Text(
                          'TEMPORAL ANALYSIS',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'This app is not a substitute for professional mental health care.',
                  style: TextStyle(
                    color: Colors.white30,
                    fontSize: 10,
                    letterSpacing: 0.3,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),

                _NeonPanel(
                  label: 'BIOMETRIC INPUT',
                  accentColor: AppColors.neonCyan,
                  child: _NeonSlider(
                    label: 'ENERGY',
                    value: _energy,
                    color: AppColors.neonCyan,
                    onChanged: (v) => setState(() {
                      _energy = v;
                      _saved = false;
                    }),
                  ),
                ),
                const SizedBox(height: 16),

                _NeonPanel(
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
                const SizedBox(height: 16),

                _NeonPanel(
                  label: 'NEURAL DUMP',
                  accentColor: AppColors.neonViolet,
                  trailing: _MicButton(
                    onTap: () {
                      final voice = ref.read(voiceControllerProvider.notifier);
                      final isListening =
                          ref.read(voiceControllerProvider).isListening;
                      if (isListening) {
                        voice.stopListening();
                      } else {
                        voice.startListening();
                      }
                    },
                    isListening: ref.watch(voiceControllerProvider).isListening,
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLines: 5,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.6,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Capture any thoughts, wins, or blockers...',
                      hintStyle: TextStyle(color: Colors.white24),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => setState(() => _saved = false),
                  ),
                ),
                const SizedBox(height: 16),

                _NeonPanel(
                  label: "TODAY'S PROMPT",
                  accentColor: AppColors.memoryAmber,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.memoryAmber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.memoryAmber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline,
                          color: AppColors.memoryAmber,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'What was your highest-leverage action today?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                HoloButton(
                  label: _saving
                      ? 'SAVING...'
                      : (_saved ? 'SAVED' : 'SAVE REFLECTION'),
                  color: _saved ? AppColors.neonCyan : AppColors.neonViolet,
                  onTap: _saving ? () {} : () => _saveReflection(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NeonPanel extends StatelessWidget {
  const _NeonPanel({
    required this.label,
    required this.child,
    required this.accentColor,
    this.trailing,
  });

  final String label;
  final Widget child;
  final Color accentColor;
  final Widget? trailing;

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
              if (trailing != null) ...[
                const Spacer(),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _NeonSlider extends StatelessWidget {
  const _NeonSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
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
            Text(
              label,
              style: const TextStyle(
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

class _MicButton extends StatelessWidget {
  const _MicButton({required this.onTap, required this.isListening});

  final VoidCallback onTap;
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isListening
              ? AppColors.memoryAmber.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isListening
                ? AppColors.memoryAmber.withValues(alpha: 0.5)
                : Colors.white24,
          ),
        ),
        child: Icon(
          isListening ? Icons.mic : Icons.mic_none,
          size: 16,
          color: isListening ? AppColors.memoryAmber : Colors.white38,
        ),
      ),
    );
  }
}
