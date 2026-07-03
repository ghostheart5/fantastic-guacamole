import 'package:fantastic_guacamole/core/constants/app_assets.dart';
import 'package:fantastic_guacamole/core/widgets/smart_pressable.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/features/home/widgets/ai_decision_card.dart';
import 'package:fantastic_guacamole/features/home/widgets/energy_card.dart';
import 'package:fantastic_guacamole/features/home/widgets/focus_task_card.dart';
import 'package:fantastic_guacamole/features/home/widgets/quick_actions.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/theme/theme.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/app_background.dart';
import 'package:fantastic_guacamole/ui/widgets/holo_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SmartCoachScreen extends ConsumerStatefulWidget {
  const SmartCoachScreen({super.key});

  @override
  ConsumerState<SmartCoachScreen> createState() => _SmartCoachScreenState();
}

class _SmartCoachScreenState extends ConsumerState<SmartCoachScreen> {
  String? _lastTaskId;
  String? _lastSpokenReasoning;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AIRecommendation?>>(aiResponseProvider, (prev, next) {
      final String? newId = next.value?.task?.id;
      if (newId != null && newId != _lastTaskId) {
        _lastTaskId = newId;
        ref.read(audioFeedbackControllerProvider).playDecision();
      }

      final String? reasoning = next.value?.reasoning;
      if (reasoning != null &&
          reasoning.isNotEmpty &&
          reasoning != _lastSpokenReasoning) {
        _lastSpokenReasoning = reasoning;
        ref.read(voiceServiceProvider).speak(reasoning);
      }
    });

    final AsyncValue<AIRecommendation?> aiAsync = ref.watch(aiResponseProvider);
    final AIRecommendation? recommendation = aiAsync.asData?.value;
    final String taskTitle = recommendation?.task?.title ?? '';
    final predictionAsync = taskTitle.isEmpty
        ? null
        : ref.watch(predictionProvider(taskTitle));
    final AIPersonality personality = ref.watch(aiPersonalityProvider);
    final double energy = ref.watch(energyProvider);
    final VoiceState voice = ref.watch(voiceControllerProvider);

    return AppBackground(
      active: true,
      child: AnimatedSystemBackground(
        backgroundAssetPath: AppAssets.bgHome,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SmartPressable(
                              onTap: () =>
                                  ref.read(appFlowProvider.notifier).toCoach(),
                              child: const Icon(
                                Icons.arrow_back_ios,
                                color: Colors.white54,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'SMART COACH',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'AI-POWERED TASK SELECTION',
                                  style: TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 2,
                                    color: Colors.white38,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  NeonPanel(
                    header: Text(
                      'AI PERSONALITY',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: neonCyan,
                        letterSpacing: 2,
                      ),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AIPersonality.values.map((AIPersonality tone) {
                        final bool selected = personality == tone;
                        return ChoiceChip(
                          label: Text(_personalityLabel(tone)),
                          selected: selected,
                          onSelected: (_) {
                            ref.read(aiPersonalityProvider.notifier).set(tone);
                            ref
                                .read(aiResponseProvider.notifier)
                                .execute(personalityOverride: tone);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (predictionAsync != null)
                    NeonPanel(
                      header: Text(
                        'PREDICTION',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: neonCyan,
                          letterSpacing: 2,
                        ),
                      ),
                      child: predictionAsync.when(
                        data: (prediction) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Prediction: ${prediction.outcome}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Confidence: ${(prediction.probability * 100).toInt()}%',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, _) => const Text('Prediction unavailable'),
                      ),
                    ),
                  if (predictionAsync != null) const SizedBox(height: 16),
                  if (recommendation?.task case final task?) ...[
                    NeonPanel(
                      header: Text(
                        'AI RECOMMENDATION',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: neonCyan,
                          letterSpacing: 2,
                        ),
                      ),
                      child: AIDecisionCard(
                        task: task,
                        reasoning: recommendation?.reasoning,
                        emotion: recommendation?.emotion,
                        confidence: recommendation?.confidence,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FocusTaskCard(task: task),
                    const SizedBox(height: 16),
                  ],
                  NeonPanel(
                    header: Text(
                      'ENERGY LEVEL',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: neonCyan,
                        letterSpacing: 2,
                      ),
                    ),
                    child: EnergyCard(energy: energy),
                  ),
                  const SizedBox(height: 24),
                  QuickActions(
                    label: 'Start Focus Session',
                    icon: Icons.bolt,
                    onPrimary: () {
                      final task = recommendation?.task;
                      if (task != null) {
                        ref.read(focusTaskProvider.notifier).set(task);
                      }
                      ref.read(focusControllerProvider.notifier).start();
                      ref.read(appFlowProvider.notifier).toFocus();
                    },
                  ),
                  const SizedBox(height: 12),
                  HoloButton(
                    label: voice.isListening ? 'Stop Listening' : '🎤 Speak',
                    onTap: () {
                      if (voice.isListening) {
                        ref
                            .read(voiceControllerProvider.notifier)
                            .stopListening();
                      } else {
                        ref
                            .read(voiceControllerProvider.notifier)
                            .startListening();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  NeonPanel(
                    header: Text(
                      'VOICE INTERACTION',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: neonCyan,
                        letterSpacing: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                voice.isListening
                                    ? 'Listening...'
                                    : 'Tap mic and speak to SI',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: voice.isListening
                                          ? neonCyan
                                          : Colors.white70,
                                    ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                if (voice.isListening) {
                                  ref
                                      .read(voiceControllerProvider.notifier)
                                      .stopListening();
                                } else {
                                  ref
                                      .read(voiceControllerProvider.notifier)
                                      .startListening();
                                }
                              },
                              icon: Icon(
                                voice.isListening ? Icons.mic_off : Icons.mic,
                                color: voice.isListening
                                    ? Colors.pinkAccent
                                    : neonCyan,
                              ),
                            ),
                          ],
                        ),
                        if (voice.recognizedText.isNotEmpty)
                          Text(
                            'You: ${voice.recognizedText}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white60),
                          ),
                        if (voice.lastResponse.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'SI: ${voice.lastResponse}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFF9BE7FF)),
                            ),
                          ),
                        if (voice.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              voice.error ?? 'Voice interaction failed.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFFFF8A8A)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _personalityLabel(AIPersonality personality) {
    switch (personality) {
      case AIPersonality.coach:
        return 'Coach';
      case AIPersonality.strict:
        return 'Strict';
      case AIPersonality.calm:
        return 'Calm';
      case AIPersonality.neutral:
        return 'Neutral';
    }
  }
}
