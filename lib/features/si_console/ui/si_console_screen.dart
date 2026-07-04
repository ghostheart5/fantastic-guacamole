import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fantastic_guacamole/core/constants/app_assets.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/utils/crisis_guard.dart';
import 'package:fantastic_guacamole/data/models/si_state.dart';
import 'package:fantastic_guacamole/features/emotion/emotion_provider.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/widgets/typing_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

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
// Response logic
// ---------------------------------------------------------------------------

class _SIResponder {
  _SIResponder({
    required this.energy,
    required this.siState,
    required this.profile,
    required this.aiResponse,
    required this.focus,
    required this.variationSeed,
  });

  final double energy;
  final SIState siState;
  final ProfileState profile;
  final AIRecommendation? aiResponse;
  final FocusState focus;
  final int variationSeed;

  ({String text, String emotion}) respond(String input) {
    final String q = input.toLowerCase().trim();

    if (_any(q, [
      'hello',
      'hi ',
      'hey',
      'wake up',
      'wake',
      'are you online',
      'are you there',
    ])) {
      return _greeting();
    }
    if (_any(q, [
      'help',
      'commands',
      'what can you',
      'capabilities',
      'how do i use',
    ])) {
      return _help();
    }
    if (_any(q, [
      'status',
      'system report',
      'overview',
      'dashboard',
      'full report',
    ])) {
      return _status();
    }
    if (_any(q, [
      'energy',
      'tired',
      'exhausted',
      'fatigue',
      'how am i doing',
      'how am i',
      'my state',
      'feeling',
    ])) {
      return _energyCheck();
    }
    if (_any(q, [
      'start session',
      'start focus',
      'start timer',
      'focus session',
      'timer',
      'active session',
      'my session',
      'current session',
      'begin session',
    ])) {
      return _focusSession();
    }
    if (_any(q, [
      'level',
      'xp',
      'experience',
      'my progress',
      'my rank',
      'rank',
      'streak',
      'how much xp',
      'how far',
    ])) {
      return _progression();
    }
    if (_any(q, [
      'what should i',
      'recommend',
      'suggest',
      'next task',
      'which task',
      'what task',
      "what's next",
      'assign me',
      'give me a task',
      'optimal task',
    ])) {
      return _taskRecommendation();
    }
    return _fallback();
  }

  String _pick(List<String> options, {String context = ''}) {
    final int base =
        variationSeed +
        context.hashCode.abs() +
        siState.completedToday +
        profile.level;
    final int index = base % options.length;
    return options[index];
  }

  bool _any(String input, List<String> keywords) =>
      keywords.any((k) => input.contains(k));

  ({String text, String emotion}) _greeting() {
    final int pct = (energy * 100).round();
    return (
      text: _pick([
        'System online. I monitor your energy, analyze your task queue, and track session performance. What do you need?',
        'Strategic Intelligence active. Current energy reads $pct%. Ready to assist - what is your query?',
        'Online and calibrated. ${profile.streak > 0 ? 'Streak at ${profile.streak} days.' : 'No active streak - let\'s start one.'} What do you need?',
        energy > 0.65
            ? 'Systems nominal. Running at $pct% - solid window for deep work. What is the objective?'
            : 'Online. Energy is at $pct% - I will keep recommendations conservative. What do you need?',
      ], context: 'greeting'),
      emotion: 'confident',
    );
  }

  ({String text, String emotion}) _help() => (
    text: _pick([
      'Available queries:\n'
          '- recommend / what should i - AI task suggestion\n'
          '- energy / tired / how am i - energy profile\n'
          '- status / overview - full system report\n'
          '- focus session / timer - session status\n'
          '- level / xp / streak - progression\n'
          '- hello - reinitialize\n\n'
          'Natural language also works. I parse intent.',
      'I respond to:\n'
          '-> Task queries: "what should I do", "recommend a task"\n'
          '-> Energy: "how am I doing", "am I tired"\n'
          '-> Progress: "my level", "how much XP", "my streak"\n'
          '-> Session: "focus session", "start timer"\n'
          '-> Overview: "status", "full report"\n\n'
          'Or just describe what you are thinking - I will interpret it.',
    ], context: 'help'),
    emotion: 'balanced',
  );

  ({String text, String emotion}) _status() => (
    text:
        'SYSTEM STATUS\n'
        '------------------\n'
        'Energy    ${(energy * 100).round()}%\n'
        'Fatigue   ${(siState.fatigue * 100).round()}%\n'
        'Level     ${profile.level}\n'
        'XP        ${profile.xp}\n'
        'Streak    ${profile.streak}d\n'
        'Sessions  ${siState.completedToday} today\n'
        '------------------\n'
        '${focus.active ? 'SESSION    ACTIVE' : 'SESSION    Idle'}',
    emotion: 'balanced',
  );

  ({String text, String emotion}) _energyCheck() {
    final int pct = (energy * 100).round();
    final int fatigue = (siState.fatigue * 100).round();
    if (energy < 0.35) {
      return (
        text: _pick([
          'Energy at $pct% - below recovery threshold. Fatigue is $fatigue%. Redirect to lightweight tasks or a rest block before pushing further.',
          'Low energy state: $pct%. ${siState.completedToday} sessions today - that is likely a factor. Consider a break before your next block.',
          'Running at $pct%. Fatigue index: $fatigue%. Forcing output at this level degrades quality - lighter tasks or rest recommended.',
        ], context: 'energy-low'),
        emotion: 'cautious',
      );
    } else if (energy > 0.7) {
      return (
        text: _pick([
          'Energy at $pct% - peak performance window. Fatigue: $fatigue%. Optimal time for high-priority deep work.',
          'High energy: $pct%. Fatigue is low at $fatigue%. Use this window for your hardest task - do not waste it on admin.',
          '$pct% energy, $fatigue% fatigue. ${siState.completedToday} sessions logged. You are in the zone - prioritize something that matters.',
        ], context: 'energy-high'),
        emotion: 'confident',
      );
    } else {
      return (
        text: _pick([
          'Energy at $pct% - moderate range. Fatigue: $fatigue%. ${siState.completedToday} sessions completed. Maintain current cadence.',
          'You are at $pct% - not depleted, not peak. ${energy > 0.55 ? 'Medium-priority tasks suit this window.' : 'Avoid over-committing - stay with manageable tasks.'}',
          'Moderate energy: $pct%. Fatigue $fatigue%. Enough for focused work - avoid stacking back-to-back deep sessions.',
        ], context: 'energy-mid'),
        emotion: 'balanced',
      );
    }
  }

  ({String text, String emotion}) _focusSession() {
    if (focus.active) {
      final String elapsed =
          '${(focus.seconds ~/ 60).toString().padLeft(2, '0')}:${(focus.seconds % 60).toString().padLeft(2, '0')}';
      return (
        text: _pick([
          'Focus session active - $elapsed elapsed. Return to the session screen to continue tracking.',
          'Active session running: $elapsed in. Stay on target - I will log completion when you finish.',
          'Session is live. $elapsed on the clock. Do not break focus - return to the session screen.',
        ], context: 'focus-active'),
        emotion: 'focused',
      );
    }
    final int pct = (energy * 100).round();
    return (
      text: _pick([
        'No active session. Navigate to Nexus and tap Start Focus to initiate a block. I\'ll track your performance.',
        'Session is idle. Head to Nexus -> Start Focus. ${energy > 0.5 ? 'Energy looks good for a full block.' : 'Given your energy ($pct%), a shorter block may be more effective.'}',
        'No focus session running. Start one from the Nexus screen. Current energy: $pct% - ${energy > 0.6 ? 'a solid window.' : 'consider starting light.'}',
      ], context: 'focus-idle'),
      emotion: 'driven',
    );
  }

  ({String text, String emotion}) _progression() {
    final int toNext = 50 - (profile.xp % 50);
    return (
      text: _pick([
        'Level ${profile.level} - ${profile.xp} XP total. $toNext to next level. Streak: ${profile.streak} days.',
        '${profile.xp} XP accumulated. $toNext more to level ${profile.level + 1}. ${profile.streak > 0 ? '${profile.streak}-day streak active - XP multiplier in effect.' : 'Starting a streak will boost XP gain.'}',
        'Progress: Level ${profile.level}, $toNext XP from the next threshold. ${siState.completedToday > 0 ? '${siState.completedToday} session${siState.completedToday == 1 ? '' : 's'} logged today.' : 'No sessions today - complete one to earn XP.'}',
      ], context: 'progression'),
      emotion: profile.streak > 3 ? 'driven' : 'balanced',
    );
  }

  ({String text, String emotion}) _taskRecommendation() {
    if (aiResponse == null) {
      return (
        text: _pick([
          'No task data in the queue. Head to Creator to add tasks - then I can give you a proper recommendation.',
          'Task queue is empty. I can\'t recommend what doesn\'t exist. Populate your task list first.',
          'Nothing in the queue to analyze. Add tasks from the Creator screen, then ask again.',
        ], context: 'task-empty'),
        emotion: 'balanced',
      );
    }
    final String message = aiResponse?.message ?? 'No active tasks queued.';
    return (text: message, emotion: aiResponse?.emotion ?? 'balanced');
  }

  ({String text, String emotion}) _fallback() => (
    text: _pick([
      'I didn\'t parse a recognized intent. Try: "status", "energy", "recommend a task", or "help".',
      'Query unclear. I work best with direct requests - try "what should I do", "how is my energy", or "system status".',
      'Not sure what you\'re asking. Current read: energy ${(energy * 100).round()}%, level ${profile.level}. Type "help" for available commands.',
      'Unrecognized input. I handle tasks, energy, focus sessions, and progression queries. Type "help" to see examples.',
    ], context: 'fallback'),
    emotion: 'balanced',
  );
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
  String? _lastSiResponse;
  int _variationCounter = 0;
  late final AnimationController _typingAnim;

  @override
  void initState() {
    super.initState();
    _typingAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // Greeting after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addSI(
        'System online. Strategic Intelligence interface active.\n'
        'I have access to your task queue, energy profile, and session history. '
        'Ask me anything - or type "help" to see available commands.',
        emotion: 'confident',
      );
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _typingAnim.dispose();
    super.dispose();
  }

  void _addSI(String text, {String emotion = 'balanced'}) {
    setState(
      () => _messages.add(_Msg(text: text, isUser: false, emotion: emotion)),
    );
    _scrollToBottom();
  }

  void _send() {
    final String text = _input.text.trim();
    if (text.isEmpty) return;
    if (isCrisis(text)) {
      showCrisisDialog(context);
      return;
    }
    _input.clear();

    setState(() => _messages.add(_Msg(text: text, isUser: true)));
    _scrollToBottom();
    setState(() => _typing = true);
    _scrollToBottom();

    _dispatchQuery(text);
  }

  Future<void> _dispatchQuery(String text) async {
    final endpoint = Env.aiProxyEndpoint.trim();
    if (endpoint.isNotEmpty) {
      try {
        await _sendToProxy(text, endpoint);
        return;
      } catch (_) {
        // fall through to canned responder
      }
    }
    _useCannedResponse(text);
  }

  Future<void> _sendToProxy(String text, String endpoint) async {
    final energy = ref.read(energyProvider);
    final siState = ref.read(siStateProvider);
    final profile = ref.read(profileProvider);
    final emotion = ref.read(emotionProvider);

    // Build conversation history for context (last 6 messages)
    final recentMessages = _messages.length > 6
        ? _messages.sublist(_messages.length - 6)
        : _messages;
    final history = recentMessages
        .map(
          (_Msg m) => <String, String>{
            'role': m.isUser ? 'user' : 'assistant',
            'content': m.text,
          },
        )
        .toList();

    final body = jsonEncode({
      'message': text,
      'history': history,
      'context': {
        'name': profile.name,
        'level': profile.level,
        'xp': profile.xp,
        'streak': profile.streak,
        'energy': energy,
        'emotion': emotion.name,
        'fatigue': siState.fatigue,
        'completedToday': siState.completedToday,
      },
    });

    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 12));

    if (!mounted) return;

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final message =
          json['message']?.toString() ??
          json['reply']?.toString() ??
          'No response.';
      final emotion = json['emotion']?.toString() ?? 'balanced';
      setState(() {
        _typing = false;
        _messages.add(_Msg(text: message, isUser: false, emotion: emotion));
      });
      _scrollToBottom();
    } else {
      throw Exception('Proxy returned ${response.statusCode}');
    }
  }

  void _useCannedResponse(String text) {
    final Duration delay = Duration(
      milliseconds: 600 + math.Random().nextInt(700),
    );
    Timer(delay, () {
      if (!mounted) return;
      final energy = ref.read(energyProvider);
      final siState = ref.read(siStateProvider);
      final profile = ref.read(profileProvider);
      final aiResponse = ref.read(aiResponseProvider).asData?.value;
      final focus = ref.read(focusControllerProvider);

      final responder = _SIResponder(
        energy: energy,
        siState: siState,
        profile: profile,
        aiResponse: aiResponse,
        focus: focus,
        variationSeed: _variationCounter++,
      );

      var result = responder.respond(text);
      int retries = 0;
      while (_lastSiResponse != null &&
          result.text == _lastSiResponse &&
          retries < 3) {
        result = _SIResponder(
          energy: energy,
          siState: siState,
          profile: profile,
          aiResponse: aiResponse,
          focus: focus,
          variationSeed: _variationCounter++,
        ).respond(text);
        retries++;
      }
      setState(() {
        _typing = false;
        _messages.add(
          _Msg(text: result.text, isUser: false, emotion: result.emotion),
        );
        _lastSiResponse = result.text;
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final engineStateAsync = ref.watch(siEngineStateProvider);
    final String? engineSnapshot = engineStateAsync.when(
      data: (state) {
        if (state == null) return null;
        final String? personality = state['personality']?.toString();
        final String? emotion = state['emotion']?.toString();
        final dynamic rawConfidence = state['confidence'];
        final String confidence = rawConfidence is num
            ? '${(rawConfidence * 100).round()}%'
            : '';
        final List<String> parts = <String>[
          if (personality != null && personality.isNotEmpty) personality,
          if (emotion != null && emotion.isNotEmpty) emotion,
          if (confidence.isNotEmpty) confidence,
        ];
        if (parts.isEmpty) return null;
        return parts.join(' · ').toUpperCase();
      },
      loading: () => null,
      error: (_, _) => null,
    );

    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgSiConsole,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                onBack: () => ref.read(appFlowProvider.notifier).toCoach(),
                engineSnapshot: engineSnapshot,
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
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
              _InputBar(controller: _input, onSend: _send),
            ],
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
            child: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white54,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
            ),
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
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 2,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
                if (engineSnapshot != null) ...[
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      engineSnapshot ?? '',
                      style: const TextStyle(
                        fontSize: 8,
                        letterSpacing: 1,
                        color: Colors.white54,
                      ),
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
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _SIAvatar(emotion: msg.emotion),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
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
                        animate: !isUser,
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
                    onTap: () => unawaited(
                      ref.read(voiceServiceProvider).speak(msg.text),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
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
                            size: 12,
                          ),
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
        boxShadow: [
          BoxShadow(color: _color.withValues(alpha: 0.25), blurRadius: 8),
        ],
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
  const _InputBar({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: AppColors.neonCyan,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Query the system...',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF0A1520),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
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
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 44,
              height: 44,
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
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
