import 'dart:async';

import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/responsive_layout.dart';
import 'package:flutter/material.dart';

class FocusSessionSheet extends StatefulWidget {
  const FocusSessionSheet({
    required this.directive,
    required this.onReviewTimeline,
    required this.onAdjustPlan,
    this.taskTitle,
    this.onMarkTaskComplete,
    super.key,
  });

  final String directive;
  final VoidCallback onReviewTimeline;
  final VoidCallback onAdjustPlan;
  final String? taskTitle;
  final Future<void> Function()? onMarkTaskComplete;

  @override
  State<FocusSessionSheet> createState() => _FocusSessionSheetState();
}

class _FocusSessionSheetState extends State<FocusSessionSheet> {
  static const Duration _sessionLength = Duration(minutes: 12);
  Duration _remaining = _sessionLength;
  Timer? _ticker;
  bool _running = false;
  bool _complete = false;
  bool _showRecovery = false;
  bool _markingTaskComplete = false;
  bool _taskMarkedComplete = false;
  String? _taskCompletionError;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    if (_complete) return;
    if (_running) {
      _ticker?.cancel();
      setState(() => _running = false);
      return;
    }

    setState(() => _running = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remaining <= const Duration(seconds: 1)) {
        timer.cancel();
        setState(() {
          _remaining = Duration.zero;
          _running = false;
          _complete = true;
        });
        return;
      }
      setState(() => _remaining -= const Duration(seconds: 1));
    });
  }

  void _finishNow() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      _complete = true;
    });
  }

  Future<void> _markTaskComplete() async {
    final Future<void> Function()? markTaskComplete = widget.onMarkTaskComplete;
    if (markTaskComplete == null ||
        _markingTaskComplete ||
        _taskMarkedComplete) {
      return;
    }

    setState(() {
      _markingTaskComplete = true;
      _taskCompletionError = null;
    });
    try {
      await markTaskComplete();
      if (!mounted) {
        return;
      }
      setState(() => _taskMarkedComplete = true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _taskCompletionError = 'Could not mark this task complete. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _markingTaskComplete = false);
      }
    }
  }

  String get _timeLabel {
    final int minutes = _remaining.inMinutes;
    final int seconds = _remaining.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final double elapsed =
        1 - (_remaining.inSeconds / _sessionLength.inSeconds).clamp(0.0, 1.0);
    final Color accent = _complete
        ? const Color(0xFF7AF7C4)
        : AppColors.neonCyan;

    return SafeArea(
      top: false,
      child: ResponsiveContent(
        maxWidth: 640,
        alignment: Alignment.bottomCenter,
        child: Material(
          color: const Color(0xFF07111F),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: SingleChildScrollView(
            padding: AppViewport.pagePadding(context).copyWith(top: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _complete
                            ? Icons.check_rounded
                            : Icons.center_focus_strong,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _complete
                            ? 'Focus block complete'
                            : 'Protect one focus block',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close focus session',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  widget.directive,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.taskTitle == null
                      ? 'This is a private, local focus block. Keep the next physical step small and visible.'
                      : 'Focus target: ${widget.taskTitle}. Completing this block will not change the task until you choose to mark it complete.',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  liveRegion: true,
                  label: _complete
                      ? 'Focus block complete.'
                      : 'Focus timer: $_timeLabel remaining.',
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: elapsed),
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      builder:
                          (BuildContext context, double value, Widget? child) {
                            return SizedBox(
                              width: 172,
                              height: 172,
                              child: Stack(
                                alignment: Alignment.center,
                                children: <Widget>[
                                  SizedBox.expand(
                                    child: CircularProgressIndicator(
                                      value: value,
                                      strokeWidth: 9,
                                      backgroundColor: Colors.white10,
                                      color: accent,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                        _complete ? 'DONE' : _timeLabel,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: _complete ? 24 : 30,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _complete
                                            ? 'Block protected'
                                            : '12 MINUTES',
                                        style: TextStyle(
                                          color: accent,
                                          fontSize: 9,
                                          letterSpacing: 1.4,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_complete) ...<Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withValues(alpha: 0.24)),
                    ),
                    child: const Text(
                      'Nice work. Capture what moved, then decide whether to continue or recover your attention.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (widget.onMarkTaskComplete != null) ...<Widget>[
                    FilledButton.icon(
                      onPressed: _taskMarkedComplete || _markingTaskComplete
                          ? null
                          : _markTaskComplete,
                      icon: Icon(
                        _taskMarkedComplete
                            ? Icons.check_circle_rounded
                            : Icons.task_alt_rounded,
                      ),
                      label: Text(
                        _taskMarkedComplete
                            ? 'Task marked complete'
                            : 'Mark focus target complete',
                      ),
                    ),
                    if (_taskCompletionError != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        _taskCompletionError!,
                        style: const TextStyle(
                          color: Color(0xFFFFA6A6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                  FilledButton.icon(
                    onPressed: widget.onReviewTimeline,
                    icon: const Icon(Icons.timeline_outlined),
                    label: const Text('Review timeline'),
                  ),
                ] else ...<Widget>[
                  FilledButton.icon(
                    onPressed: _toggleTimer,
                    icon: Icon(
                      _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      _running ? 'Pause focus' : 'Start 12-minute block',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _finishNow,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Finish now'),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _showRecovery = !_showRecovery),
                    icon: const Icon(Icons.help_outline),
                    label: const Text('I\'m stuck'),
                  ),
                  if (_showRecovery) ...<Widget>[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Shrink the next step',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Open the file, write the first line, or make the first list. If the plan is wrong, adjust it deliberately.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: widget.onAdjustPlan,
                            child: const Text('Adjust the plan in Creator'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
