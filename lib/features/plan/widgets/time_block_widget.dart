import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/features/plan/widgets/time_slot.dart';
import 'package:flutter/material.dart';

class TimeBlockWidget extends StatelessWidget {
  const TimeBlockWidget({
    super.key,
    required this.taskId,
    required this.title,
    required this.start,
    required this.end,
    required this.accent,
    this.completed = false,
    this.isCompleting = false,
    this.isNext = false,
    this.supportingText,
    this.onReviewPlan,
    this.onCompleteTask,
  });

  final String taskId;
  final String title;
  final String start;
  final String end;
  final Color accent;
  final bool completed;
  final bool isCompleting;

  /// Marks the block the planner recommends working on now.
  final bool isNext;
  final String? supportingText;
  final VoidCallback? onReviewPlan;
  final Future<void> Function(String taskId)? onCompleteTask;

  @override
  Widget build(BuildContext context) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: isNext ? 0.65 : 0.2),
          width: isNext ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isNext ? 0.22 : 0.06),
            blurRadius: isNext ? 18 : 12,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 44,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.7), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isNext) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      l10n.text(ChronoSparkString.upNext).toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (supportingText != null &&
                    supportingText!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    l10n.text(ChronoSparkString.whyThisIsNext).toUpperCase(),
                    style: TextStyle(
                      color: accent,
                      fontSize: 9,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    supportingText!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  if (onReviewPlan != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onReviewPlan,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          l10n.text(ChronoSparkString.reviewOrCorrectPlan),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: TimeSlot(start: start, end: end),
              ),
              const SizedBox(height: 6),
              if (onCompleteTask != null && !completed)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: isCompleting
                      ? SizedBox(
                          key: const ValueKey<String>('completing'),
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        )
                      : Semantics(
                          key: const ValueKey<String>('idle'),
                          button: true,
                          label: l10n.completeTaskLabel(title),
                          child: TextButton(
                            onPressed: () => onCompleteTask!(taskId),
                            style: TextButton.styleFrom(
                              foregroundColor: accent,
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              tapTargetSize: MaterialTapTargetSize.padded,
                            ),
                            child: Text(
                              l10n
                                  .text(ChronoSparkString.complete)
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.3,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                )
              else if (completed)
                Text(
                  l10n.text(ChronoSparkString.done).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.3,
                    color: Colors.white54,
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
