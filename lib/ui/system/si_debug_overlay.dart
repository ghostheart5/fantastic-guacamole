import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/focus_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/energy_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SIDebugOverlay extends StatefulWidget {
  const SIDebugOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<SIDebugOverlay> createState() => _SIDebugOverlayState();
}

class _SIDebugOverlayState extends State<SIDebugOverlay> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          bottom: 90,
          right: 16,
          child: GestureDetector(
            onLongPress: () => setState(() => _visible = !_visible),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: _visible
                  ? _DebugPanel(
                      key: const ValueKey('panel'),
                      onClose: () => setState(() => _visible = false),
                    )
                  : const _ToggleChip(key: ValueKey('chip')),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xCC0A0A16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: const Text(
        'SI',
        style: TextStyle(
          fontSize: 9,
          color: Colors.white24,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DebugPanel extends ConsumerWidget {
  const _DebugPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiAsync = ref.watch(aiResponseProvider);
    final agentTrace = ref.watch(aiAgentTraceProvider);
    final focus = ref.watch(focusControllerProvider);
    final profile = ref.watch(profileProvider);
    final energy = ref.watch(energyProvider);

    final ai = aiAsync.asData?.value;
    final double? confidence = ai?.confidence;

    return Container(
      width: 214,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xEE0A0A16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 24),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'SI DEBUG',
                  style: TextStyle(
                    fontSize: 8,
                    letterSpacing: 2,
                    color: Colors.white38,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, size: 11, color: Colors.white24),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const _Divider(),
          const SizedBox(height: 5),
          _Row('TASK', ai?.task?.title ?? '-'),
          _Row('EMOTION', ai?.emotion ?? '-'),
          _Row(
            'CONFIDENCE',
            confidence != null ? '${(confidence * 100).round()}%' : '-',
          ),
          _Row('AGENT', agentTrace?.selectedAgent ?? '-'),
          _Row('MODE', agentTrace?.mode ?? '-'),
          _Row(
            'LATENCY',
            agentTrace != null ? '${agentTrace.durationMs}ms' : '-',
          ),
          _Row('REASONING', ai?.reasoning ?? '-', wrap: true),
          const SizedBox(height: 4),
          const _Divider(),
          const SizedBox(height: 5),
          _Row('ENERGY', '${(energy * 100).round()}%'),
          _Row(
            'FOCUS',
            '${(focus.seconds ~/ 60).toString().padLeft(2, '0')}:'
                '${(focus.seconds % 60).toString().padLeft(2, '0')}',
          ),
          _Row(
            'SESSION',
            focus.active
                ? 'ACTIVE'
                : focus.completed
                ? 'DONE'
                : 'IDLE',
          ),
          const SizedBox(height: 4),
          const _Divider(),
          const SizedBox(height: 5),
          _Row('XP', '${profile.xp}'),
          _Row('LEVEL', '${profile.level}'),
          _Row('STREAK', '${profile.streak}d'),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(color: Colors.white10, height: 1, thickness: 0.5);
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.wrap = false});

  final String label;
  final String value;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: wrap
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 8,
                color: Colors.white38,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 8, color: Colors.white60),
              maxLines: wrap ? 4 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
