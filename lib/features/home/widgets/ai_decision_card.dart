import 'package:fantastic_guacamole/state/models/task_view.dart';
import 'package:fantastic_guacamole/ui/widgets/widgets.dart';
import 'package:flutter/material.dart';

class AIDecisionCard extends StatefulWidget {
  const AIDecisionCard({
    super.key,
    required this.task,
    this.title = 'SMART RECOMMENDATION',
    this.reasoning,
    this.emotion,
    this.confidence,
  });

  final TaskView task;
  final String title;
  final String? reasoning;
  final String? emotion;
  final double? confidence;

  @override
  State<AIDecisionCard> createState() => _AIDecisionCardState();
}

class _AIDecisionCardState extends State<AIDecisionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _glow = Tween<double>(
      begin: 6,
      end: 22,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? emotion = widget.emotion;
    final double? confidence = widget.confidence;
    final String? reasoning = widget.reasoning;

    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withValues(alpha: 0.15),
              blurRadius: _glow.value,
              spreadRadius: 0,
            ),
          ],
        ),
        child: child,
      ),
      child: AppColumn(
        gap: 2,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppText(
            widget.title,
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              color: Colors.white54,
            ),
          ),
          AppText(
            widget.task.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          AppText(
            'Priority ${widget.task.priority}  ·  Energy ${widget.task.energyRequired}',
            style: const TextStyle(fontSize: 12, color: Colors.blueAccent),
          ),
          if (emotion != null || confidence != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (emotion != null) _EmotionChip(emotion),
                if (emotion != null && confidence != null)
                  const SizedBox(width: 8),
                if (confidence != null) _ConfidenceChip(confidence),
              ],
            ),
          ],
          if (reasoning != null) ...[
            const SizedBox(height: 8),
            AppText(
              reasoning,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white54,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmotionChip extends StatelessWidget {
  const _EmotionChip(this.emotion);
  final String emotion;

  Color get _color {
    switch (emotion) {
      case 'focused':
        return Colors.blueAccent;
      case 'confident':
        return Colors.greenAccent;
      case 'driven':
        return Colors.orangeAccent;
      case 'strained':
        return Colors.redAccent;
      case 'cautious':
        return Colors.amber;
      default:
        return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        emotion.toUpperCase(),
        style: TextStyle(fontSize: 9, color: _color, letterSpacing: 1.5),
      ),
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip(this.confidence);
  final double confidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
      child: Text(
        '${(confidence * 100).round()}% CONF',
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white38,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
