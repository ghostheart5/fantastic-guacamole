import 'dart:async';
import 'dart:math' as math;

import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_console_query_controller.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
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
    unawaited(ref.read(voiceServiceProvider).stop());
    unawaited(_goalEventSubscription?.cancel());
    _input.dispose();
    _scroll.dispose();
    _typingAnim.dispose();
    super.dispose();
  }

  void _addSI(String text, {String emotion = 'balanced'}) {
    _safeSetState(() => _messages.add(_Msg(text: text, isUser: false, emotion: emotion)));
    _scrollToBottom();
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
                '- /plan: summarize schedule and next blocks\n'
                '- /timeline: summarize recent milestones/events\n'
                '- /trajectory: summarize momentum, pressure, and prediction\n\n'
                'High-signal prompts SI responds well to:\n'
                '- "List my 3 newest tasks and what to do first."\n'
                '- "Did I create a task just now? Show the latest task title."\n'
                '- "Summarize trajectory pressure and one corrective action."\n'
                '- "Show plan risks for today and 3 next actions."\n'
                '- "Summarize goals at risk and what to do next."\n\n'
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
                '- flowmap: ${aggregation.flowmapNodes.length}\n'
                '- plan preview blocks: ${aggregation.planPreview.length}\n\n'
                'Trajectory:\n'
                '- pressure: ${aggregation.trajectory.pressureIndex}\n'
                '- momentum: ${(aggregation.trajectory.momentum * 100).round()}%\n'
                '- divergence: ${aggregation.trajectory.behaviorDivergence}%\n\n'
                'Use /tasks, /goals, /plan, /timeline, /trajectory for module-specific responses.';

      _safeSetState(() {
        _messages.add(_Msg(text: text, isUser: true));
        _messages.add(_Msg(text: status, isUser: false, emotion: 'focused'));
      });
      _scrollToBottom();
      return true;
    }

    if (command == '/tasks' ||
        command == '/goals' ||
        command == '/plan' ||
        command == '/timeline' ||
        command == '/trajectory') {
      final String response = _localSurfaceSummary(command, aggregation);
      _safeSetState(() {
        _messages.add(_Msg(text: text, isUser: true));
        _messages.add(_Msg(text: response, isUser: false, emotion: 'focused'));
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
      case '/timeline':
        final List<String> events = aggregation.timeline
            .take(3)
            .map((e) => '${e.shortLabel}: ${e.title}')
            .toList(growable: false);
        final String eventsText = events.isEmpty
            ? 'No timeline events yet.'
            : events.map((e) => '- $e').join('\n');
        return 'TIMELINE SNAPSHOT\n\nEvents: ${aggregation.timeline.length}\n\nRecent events:\n$eventsText\n\nPrompt: "summarize the last events and what pattern they show."';
      case '/trajectory':
        return 'TRAJECTORY SNAPSHOT\n\nPressure: ${aggregation.trajectory.pressureIndex}\nMomentum: ${(aggregation.trajectory.momentum * 100).round()}%\nDivergence: ${aggregation.trajectory.behaviorDivergence}%\nAlert: ${aggregation.trajectory.alert}\n\nPrompt: "give me one action to improve momentum today."';
      default:
        return 'Module command not recognized.';
    }
  }

  Future<void> _dispatchQuery(String text) async {
    try {
      final recommendation = await ref.read(aiControllerProvider).sendMessage(text);
      if (!mounted) return;
      final String message = recommendation?.message.trim() ?? '';
      if (message.isEmpty) {
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
    } on Exception {
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
  const _Header({required this.onBack, this.engineSnapshot});
  final VoidCallback onBack;
  final String? engineSnapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
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
          const Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'SI CONSOLE',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'ONLINE',
                    style: TextStyle(fontSize: 9, letterSpacing: 2, color: Colors.greenAccent),
                  ),
                ),
                if (engineSnapshot != null) ...[
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      engineSnapshot ?? '',
                      style: const TextStyle(fontSize: 8, letterSpacing: 1, color: Colors.white54),
                    ),
                  ),
                ],
              ],
            ),
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
