part of 'timeline_screen.dart';

class _TimelineSourceNotice extends StatelessWidget {
  const _TimelineSourceNotice({required this.issue, required this.onRetry});

  final _TimelineSourceIssue issue;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ({IconData icon, Color color, String text, String semantics})
    content = switch (issue) {
      _TimelineSourceIssue.persistence => (
        icon: Icons.inventory_2_outlined,
        color: AppColors.recallRed,
        text:
            'Some saved Timeline activity could not be read. Valid activity is shown; preserve the original before repairing it.',
        semantics:
            'Some saved Timeline activity could not be read. Valid activity is shown. Preserve the original before repairing it.',
      ),
      _TimelineSourceIssue.taskError => (
        icon: Icons.sync_problem_rounded,
        color: AppColors.recallRed,
        text:
            'Task projections are unavailable. Saved Timeline activity is still shown.',
        semantics:
            'Task projections are unavailable. Saved Timeline activity is still shown.',
      ),
      _TimelineSourceIssue.taskLoading => (
        icon: Icons.hourglass_top_rounded,
        color: AppColors.neonCyan,
        text:
            'Task projections are still loading. Saved Timeline activity is shown below.',
        semantics:
            'Task projections are still loading. Saved Timeline activity is shown below.',
      ),
    };
    return Semantics(
      liveRegion: true,
      label: journeyLabel(context, content.semantics),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF08131F).withValues(alpha: 0.94),
          border: Border.all(color: content.color.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: <Widget>[
            Icon(content.icon, color: content.color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                journeyLabel(context, content.text),
                style: const TextStyle(
                  color: Color(0xFFD8E1EF),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(width: 8),
              IconButton(
                key: Key(
                  issue == _TimelineSourceIssue.persistence
                      ? 'timeline-persistence-notice-retry'
                      : 'timeline-task-notice-retry',
                ),
                tooltip: issue == _TimelineSourceIssue.persistence
                    ? journeyText(
                        context,
                        'Preserve and repair Timeline source',
                        'Conservar y reparar la fuente de la Línea de Tiempo',
                      )
                    : journeyText(context, 'Retry source', 'Reintentar fuente'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
