import 'dart:async';
import 'dart:math' as math;

import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/widgets/smart_pressable.dart';
import 'package:fantastic_guacamole/features/focus/logic/session_timer.dart';
import 'package:fantastic_guacamole/features/focus/services/focus_session_services.dart';
import 'package:fantastic_guacamole/features/focus/widgets/focus_timer.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/models/task_view.dart';
import 'package:fantastic_guacamole/theme/theme.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/holo_button.dart';
import 'package:fantastic_guacamole/ui/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:vibration/vibration.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> with TickerProviderStateMixin {
  static const _durationOptions = [15, 25, 50];

  int _selectedMinutes = 25;
  bool _started = false;
  late int _seconds;
  SessionTimer? _sessionTimer;
  bool _sessionCompleted = false;
  final FocusServices _focusServices = const FocusServices();

  int get _totalSeconds => _selectedMinutes * 60;

  late final AnimationController _glowPulse;
  late final AnimationController _completeAnim;

  @override
  void initState() {
    super.initState();
    _seconds = _totalSeconds;

    _glowPulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

    _completeAnim = AnimationController(vsync: this);
    _completeAnim.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateAfterComplete();
      }
    });
  }

  @override
  void dispose() {
    _sessionTimer?.dispose();
    _glowPulse.dispose();
    _completeAnim.dispose();
    super.dispose();
  }

  void _start() {
    setState(() => _started = true);
    _sessionTimer?.dispose();
    _sessionTimer = _focusServices.createTimer(
      totalSeconds: _totalSeconds,
      onTick: (remaining) {
        if (!mounted) return;
        setState(() => _seconds = remaining);
      },
      onDone: _finish,
    );
    _sessionTimer?.start();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) ref.read(audioFeedbackControllerProvider).playFocusStart();
    });
  }

  TaskView? _resolveRouteTask() {
    final Object? args = ModalRoute.of(context)?.settings.arguments;
    return args is TaskView ? args : null;
  }

  Future<void> _finish() async {
    if (_sessionCompleted) return;
    _sessionTimer?.stop();
    setState(() => _sessionCompleted = true);

    final int elapsed = _totalSeconds - _seconds;
    final TaskView? routeTask = _resolveRouteTask();
    final TaskView? selectedTask = ref.read(focusTaskProvider);
    final AIRecommendation? recommendation = ref.read(aiResponseProvider).value;
    final TaskView? task = routeTask ?? selectedTask ?? recommendation?.task;

    await ref
        .read(focusSessionControllerProvider)
        .completeSession(task: task, elapsedSeconds: elapsed, reasoning: recommendation?.reasoning);

    if (!mounted) return;

    ref.read(audioFeedbackControllerProvider).playTaskComplete();

    bool hasVibrator = false;
    try {
      // Some emulator/device implementations may return null/dynamic here.
      final Object support = await Vibration.hasVibrator();
      hasVibrator = support == true;
    } catch (_) {
      hasVibrator = false;
    }
    if (hasVibrator) {
      try {
        await Vibration.vibrate(duration: 250);
      } catch (_) {
        // Ignore vibration failures in focus-complete flow.
      }
    }
    ref.read(focusTaskProvider.notifier).set(null);
    ref.read(focusControllerProvider.notifier).complete();
  }

  Future<void> _endSession() async {
    if (_sessionCompleted) return;
    setState(() => _sessionCompleted = true);
    _sessionTimer?.stop();

    final int elapsed = (_totalSeconds - _seconds).clamp(0, _totalSeconds);
    final TaskView? routeTask = _resolveRouteTask();
    final TaskView? selectedTask = ref.read(focusTaskProvider);
    final AIRecommendation? recommendation = ref.read(aiResponseProvider).value;
    final TaskView? task = routeTask ?? selectedTask ?? recommendation?.task;

    await ref
        .read(focusSessionControllerProvider)
        .completeSession(
          task: task,
          elapsedSeconds: elapsed,
          reasoning: recommendation?.reasoning ?? 'Session ended early',
        );

    if (!mounted) return;

    ref.read(focusTaskProvider.notifier).set(null);
    ref.read(focusControllerProvider.notifier).reset();
    ref.read(appFlowProvider.notifier).toCoach();
  }

  Future<void> _skip() async {
    if (_sessionCompleted) return;
    setState(() => _sessionCompleted = true);
    _sessionTimer?.stop();

    final TaskView? routeTask = _resolveRouteTask();
    final TaskView? selectedTask = ref.read(focusTaskProvider);
    final AIRecommendation? recommendation = ref.read(aiResponseProvider).value;
    final TaskView? task = routeTask ?? selectedTask ?? recommendation?.task;

    await ref
        .read(focusSessionControllerProvider)
        .skipSession(task: task, reasoning: recommendation?.reasoning);

    if (!mounted) return;
    ref.read(focusTaskProvider.notifier).set(null);
    ref.read(focusControllerProvider.notifier).reset();
    ref.read(appFlowProvider.notifier).toCoach();
  }

  void _navigateAfterComplete() {
    if (!mounted) return;
    ref.read(focusTaskProvider.notifier).set(null);
    ref.read(focusControllerProvider.notifier).complete();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    ref.read(appFlowProvider.notifier).toInsight();
  }

  @override
  Widget build(BuildContext context) {
    final TaskView? routeTask = _resolveRouteTask();
    final TaskView? aiTask = ref.watch(aiResponseProvider).value?.task;
    final TaskView? task = routeTask ?? aiTask;
    final double elapsed = _started ? 1 - (_seconds / _totalSeconds) : 0.0;
    final safeSeconds = _seconds < 0 ? 0 : _seconds;
    final safeProgress = elapsed.isNaN || elapsed.isInfinite ? 0.0 : elapsed.clamp(0.0, 1.0);

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/focus_bg.png',
      showGradientOverlay: false,
      showGlowOverlay: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Row(
                            children: [
                              SmartPressable(
                                onTap: () {
                                  _sessionTimer?.stop();
                                  ref.read(focusControllerProvider.notifier).reset();
                                  ref.read(appFlowProvider.notifier).toCoach();
                                },
                                child: const Icon(
                                  Icons.arrow_back_ios,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: SectionHeader(
                                  title: 'FOCUS SESSION',
                                  subtitle: 'Stay locked in',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Task panel
                          if (task != null) ...[
                            NeonPanel(
                              header: Text(
                                'CURRENT TASK',
                                style: Theme.of(
                                  context,
                                ).textTheme.labelLarge?.copyWith(color: neonCyan, letterSpacing: 2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Priority ${task.priority}  ·  Energy ${task.energyRequired}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.neonCyan),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Pre-start: duration picker + begin button
                          if (!_started) ...[
                            _DurationPicker(
                              options: _durationOptions,
                              selected: _selectedMinutes,
                              onSelect: (min) => setState(() {
                                _selectedMinutes = min;
                                _seconds = _totalSeconds;
                              }),
                            ),
                            const SizedBox(height: 20),
                            HoloButton(
                              label: 'BEGIN SESSION',
                              color: AppColors.neonCyan,
                              onTap: _start,
                            ),
                          ],

                          // Active: timer + controls
                          if (_started) ...[
                            SizedBox(
                              height: math.min(340, constraints.maxHeight * 0.44),
                              child: AnimatedBuilder(
                                animation: _glowPulse,
                                builder: (context, child) {
                                  final double pulse =
                                      0.5 + 0.5 * math.sin(_glowPulse.value * math.pi);
                                  final double glowAlpha = (elapsed * 0.45 + pulse * 0.12).clamp(
                                    0.0,
                                    0.6,
                                  );
                                  return DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.neonCyan.withValues(alpha: glowAlpha),
                                          blurRadius: 16 + pulse * 14,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: child,
                                  );
                                },
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Opacity(
                                        opacity: 0.14,
                                        child: Lottie.asset(
                                          'assets/animations/focus_pulse.json',
                                          fit: BoxFit.cover,
                                          repeat: true,
                                        ),
                                      ),
                                    ),
                                    NeonPanel(
                                      child: FocusTimer(
                                        seconds: safeSeconds,
                                        progress: safeProgress,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (!_sessionCompleted) ...[
                              HoloButton(label: 'Finish Session', onTap: _finish),
                              const SizedBox(height: 12),
                              HoloButton(label: 'Skip Session', onTap: _skip),
                              const SizedBox(height: 12),
                              HoloButton(
                                label: 'End Session',
                                color: Colors.white54,
                                onTap: _endSession,
                              ),
                            ],
                          ],

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Session complete overlay
            if (_sessionCompleted)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.7),
                  child: Center(
                    child: Lottie.asset(
                      'assets/animations/session_complete.json',
                      controller: _completeAnim,
                      onLoaded: (composition) {
                        _completeAnim.duration = composition.duration;
                        if (!_completeAnim.isAnimating) {
                          _completeAnim.forward();
                        }
                      },
                      width: 280,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DurationPicker extends StatelessWidget {
  const _DurationPicker({required this.options, required this.selected, required this.onSelect});

  final List<int> options;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            SizedBox(
              width: 2,
              height: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.neonCyan,
                  borderRadius: BorderRadius.all(Radius.circular(1)),
                ),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'SESSION DURATION',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.5,
                color: AppColors.neonCyan,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: options.map((min) {
            final isSelected = min == selected;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: min != options.last ? 10 : 0),
                child: SmartPressable(
                  onTap: () => onSelect(min),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.neonCyan.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.neonCyan.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.neonCyan.withValues(alpha: 0.2),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$min',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w300,
                            color: isSelected ? AppColors.neonCyan : Colors.white38,
                          ),
                        ),
                        Text(
                          'MIN',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.5,
                            color: isSelected
                                ? AppColors.neonCyan.withValues(alpha: 0.7)
                                : Colors.white24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
