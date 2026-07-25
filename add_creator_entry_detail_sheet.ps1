$ErrorActionPreference = "Stop"

Write-Host "Adding Creator entry detail sheet..." -ForegroundColor Cyan

$file = ".\lib\features\creator\ui\widgets\creator_entry_lists.dart"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path $file)) {
  throw "Missing file: $file"
}

Copy-Item $file "$file.bak_detail_sheet" -Force

$text = Get-Content $file -Raw

$oldOpenPattern = "(?s)    void openEntry\(Task entry\) \{.*?    \}\r?\n\r?\n    return tasksAsync\.when"

$newOpen = @"
    void openEntry(Task entry) {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) {
          return _CreatorEntryDetailSheet(
            entry: entry,
            onComplete: () async {
              Navigator.of(sheetContext).maybePop();
              await completeEntry(entry);
            },
            onDelay: () async {
              Navigator.of(sheetContext).maybePop();
              await delayEntry(entry);
            },
            onSkip: () async {
              Navigator.of(sheetContext).maybePop();
              await skipEntry(entry);
            },
          );
        },
      );
    }

    return tasksAsync.when
"@

$text = [System.Text.RegularExpressions.Regex]::Replace(
  $text,
  $oldOpenPattern,
  $newOpen
)

if ($text -notmatch "class _CreatorEntryDetailSheet") {
  $detailSheet = @"

class _CreatorEntryDetailSheet extends StatelessWidget {
  const _CreatorEntryDetailSheet({
    required this.entry,
    required this.onComplete,
    required this.onDelay,
    required this.onSkip,
  });

  final Task entry;
  final Future<void> Function() onComplete;
  final Future<void> Function() onDelay;
  final Future<void> Function() onSkip;

  @override
  Widget build(BuildContext context) {
    final String kind = (entry.kind ?? 'task').trim().isEmpty
        ? 'task'
        : entry.kind!.trim();
    final String description = entry.description?.trim() ?? '';
    final Color accent = _accentForKind(kind);
    final String scheduled = entry.scheduledFor == null
        ? 'Unscheduled'
        : _formatDate(entry.scheduledFor!);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF050D1A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 24,
                spreadRadius: -8,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.55),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        kind.toUpperCase(),
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  entry.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CreatorDetailPill(
                      label: 'Priority',
                      value: 'P${entry.priority}',
                      color: accent,
                    ),
                    _CreatorDetailPill(
                      label: 'Difficulty',
                      value: entry.difficulty.toString(),
                      color: AppColors.neonViolet,
                    ),
                    _CreatorDetailPill(
                      label: 'Energy',
                      value: entry.energyRequired.toString(),
                      color: AppColors.memoryAmber,
                    ),
                    _CreatorDetailPill(
                      label: 'Schedule',
                      value: scheduled,
                      color: Colors.greenAccent,
                    ),
                    _CreatorDetailPill(
                      label: 'Repeat',
                      value: entry.recurrenceRule.name,
                      color: Colors.white70,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _CreatorDetailActionButton(
                        label: 'Complete',
                        icon: Icons.check,
                        color: Colors.greenAccent,
                        onTap: onComplete,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CreatorDetailActionButton(
                        label: 'Delay',
                        icon: Icons.schedule,
                        color: AppColors.memoryAmber,
                        onTap: onDelay,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CreatorDetailActionButton(
                        label: 'Skip',
                        icon: Icons.close,
                        color: AppColors.recallRed,
                        onTap: onSkip,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _accentForKind(String kind) {
    return switch (kind.trim().toLowerCase()) {
      'goal' => AppColors.neonViolet,
      'milestone' => AppColors.memoryAmber,
      'plan' => Colors.greenAccent,
      _ => AppColors.neonCyan,
    };
  }

  static String _formatDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    return month + '/' + day + ' ' + hour + ':' + minute;
  }
}

class _CreatorDetailPill extends StatelessWidget {
  const _CreatorDetailPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorDetailActionButton extends StatelessWidget {
  const _CreatorDetailActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
"@

  $text = $text.Replace("class _CreatorTileAction extends StatelessWidget", "$detailSheet`r`nclass _CreatorTileAction extends StatelessWidget")
}

[System.IO.File]::WriteAllText($file, $text, $utf8NoBom)

Write-Host "Formatting Creator entry detail sheet..." -ForegroundColor Cyan
dart format $file

Write-Host "Applying Dart fixes..." -ForegroundColor Cyan
dart fix --apply $file

Write-Host "Formatting again..." -ForegroundColor Cyan
dart format $file

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Creator entry detail sheet is now real." -ForegroundColor Green

