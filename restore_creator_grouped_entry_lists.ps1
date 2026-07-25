$ErrorActionPreference = "Stop"

Write-Host "Exposing kind and description on Task model for Creator lists..." -ForegroundColor Cyan

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$taskModelPath = ".\lib\domain\entities\task.dart"
$taskProviderPath = ".\lib\state\providers\task_provider.dart"
$entryListsPath = ".\lib\features\creator\ui\widgets\creator_entry_lists.dart"

if (-not (Test-Path $taskModelPath)) {
  throw "Missing Task model: $taskModelPath"
}

if (-not (Test-Path $taskProviderPath)) {
  throw "Missing task provider: $taskProviderPath"
}

if (-not (Test-Path $entryListsPath)) {
  throw "Missing Creator entry lists: $entryListsPath"
}

Copy-Item $taskModelPath "$taskModelPath.bak_kind_description" -Force
Copy-Item $taskProviderPath "$taskProviderPath.bak_kind_description" -Force
Copy-Item $entryListsPath "$entryListsPath.bak_kind_description" -Force

# ------------------------------------------------------------
# Rebuild Task model with kind + description
# ------------------------------------------------------------
$taskModel = @"
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';

class Task {
  final String id;
  final String title;
  final String? description;
  final String? kind;
  final int priority;
  final int difficulty;
  final int energyRequired;
  final DateTime? scheduledFor;
  final String? goalId;
  final List<String> subtasks;
  final RecurrenceRule recurrenceRule;

  const Task({
    required this.id,
    required this.title,
    this.description,
    this.kind,
    required this.priority,
    required this.difficulty,
    required this.energyRequired,
    this.scheduledFor,
    this.goalId,
    this.subtasks = const [],
    this.recurrenceRule = RecurrenceRule.none,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Untitled',
      description: json['description'] as String?,
      kind: json['kind'] as String?,
      priority: (json['priority'] as num?)?.toInt() ?? 3,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 3,
      energyRequired: (json['energyRequired'] as num?)?.toInt() ?? 3,
      scheduledFor: DateTime.tryParse(json['scheduledFor']?.toString() ?? ''),
      goalId: json['goalId'] as String?,
      subtasks:
          (json['subtasks'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      recurrenceRule: RecurrenceRule.values.firstWhere(
        (r) => r.name == json['recurrenceRule'],
        orElse: () => RecurrenceRule.none,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (description != null) 'description': description,
    if (kind != null) 'kind': kind,
    'priority': priority,
    'difficulty': difficulty,
    'energyRequired': energyRequired,
    if (scheduledFor != null) 'scheduledFor': scheduledFor!.toIso8601String(),
    if (goalId != null) 'goalId': goalId,
    if (subtasks.isNotEmpty) 'subtasks': subtasks,
    if (recurrenceRule != RecurrenceRule.none)
      'recurrenceRule': recurrenceRule.name,
  };

  bool get hasSubtasks => subtasks.isNotEmpty;
  bool get isRecurring => recurrenceRule != RecurrenceRule.none;

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? kind,
    int? priority,
    int? difficulty,
    int? energyRequired,
    DateTime? scheduledFor,
    String? goalId,
    List<String>? subtasks,
    RecurrenceRule? recurrenceRule,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      kind: kind ?? this.kind,
      priority: priority ?? this.priority,
      difficulty: difficulty ?? this.difficulty,
      energyRequired: energyRequired ?? this.energyRequired,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      goalId: goalId ?? this.goalId,
      subtasks: subtasks ?? this.subtasks,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
    );
  }
}
"@

[System.IO.File]::WriteAllText($taskModelPath, $taskModel, $utf8NoBom)

# ------------------------------------------------------------
# Patch _taskFromEntity mappings in task_provider.dart
# ------------------------------------------------------------
$provider = Get-Content $taskProviderPath -Raw

if ($provider -notmatch "description: entity.description") {
  $provider = $provider.Replace(
"      title: entity.title,",
"      title: entity.title,
      description: entity.description,
      kind: entity.kind,"
  )
}

[System.IO.File]::WriteAllText($taskProviderPath, $provider, $utf8NoBom)

# ------------------------------------------------------------
# Rebuild CreatorEntryLists with grouping + actions
# ------------------------------------------------------------
$entryLists = @"
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreatorEntryLists extends ConsumerWidget {
  const CreatorEntryLists({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);

    Future<void> completeEntry(Task entry) async {
      await ref.read(taskActionsProvider).completeTask(entry.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Completed ${entry.title}.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }

    Future<void> delayEntry(Task entry) async {
      await ref.read(taskActionsProvider).delayTask(entry.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Delayed ${entry.title}.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }

    Future<void> skipEntry(Task entry) async {
      await ref.read(taskActionsProvider).skipTask(entry.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Skipped ${entry.title}.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }

    void openEntry(Task entry) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Opening ${entry.title} details soon.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }

    return tasksAsync.when(
      loading: () => const _CreatorEntryShell(
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.neonCyan,
            ),
          ),
        ),
      ),
      error: (_, _) => const _CreatorEntryShell(
        child: Text(
          'Creator entries could not be loaded.',
          style: TextStyle(color: AppColors.recallRed, fontSize: 12),
        ),
      ),
      data: (tasks) {
        final List<Task> all = List<Task>.from(tasks);

        final List<Task> taskEntries = all
            .where((task) => !_isCreatorSpecialKind(task.kind))
            .toList();

        final List<Task> goals = all
            .where((task) => _kindOf(task) == 'goal')
            .toList();

        final List<Task> milestones = all
            .where((task) => _kindOf(task) == 'milestone')
            .toList();

        final List<Task> planItems = all
            .where((task) => _kindOf(task) == 'plan')
            .toList();

        return _CreatorEntryShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CreatorEntryHeader(),
              const SizedBox(height: 12),
              _CreatorEntryGroup(
                label: 'Tasks',
                accent: AppColors.neonCyan,
                emptyMessage: 'No task entries yet.',
                entries: taskEntries,
                onOpen: openEntry,
                onComplete: completeEntry,
                onDelay: delayEntry,
                onSkip: skipEntry,
              ),
              const SizedBox(height: 10),
              _CreatorEntryGroup(
                label: 'Goals',
                accent: AppColors.neonViolet,
                emptyMessage: 'No goal entries yet.',
                entries: goals,
                onOpen: openEntry,
                onComplete: completeEntry,
                onDelay: delayEntry,
                onSkip: skipEntry,
              ),
              const SizedBox(height: 10),
              _CreatorEntryGroup(
                label: 'Milestones',
                accent: AppColors.memoryAmber,
                emptyMessage: 'No milestone entries yet.',
                entries: milestones,
                onOpen: openEntry,
                onComplete: completeEntry,
                onDelay: delayEntry,
                onSkip: skipEntry,
              ),
              const SizedBox(height: 10),
              _CreatorEntryGroup(
                label: 'Plan Items',
                accent: Colors.greenAccent,
                emptyMessage: 'No plan items yet.',
                entries: planItems,
                onOpen: openEntry,
                onComplete: completeEntry,
                onDelay: delayEntry,
                onSkip: skipEntry,
              ),
            ],
          ),
        );
      },
    );
  }

  static String _kindOf(Task task) {
    return (task.kind ?? '').trim().toLowerCase();
  }

  static bool _isCreatorSpecialKind(String? kind) {
    final String normalized = (kind ?? '').trim().toLowerCase();
    return normalized == 'goal' ||
        normalized == 'milestone' ||
        normalized == 'plan';
  }
}

class _CreatorEntryShell extends StatelessWidget {
  const _CreatorEntryShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonCyan.withValues(alpha: 0.08),
            blurRadius: 18,
            spreadRadius: -6,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CreatorEntryHeader extends StatelessWidget {
  const _CreatorEntryHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CREATOR ENTRIES',
          style: TextStyle(
            color: AppColors.neonCyan,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Saved tasks, goals, milestones, and plan items now surface inside Creator.',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _CreatorEntryGroup extends StatelessWidget {
  const _CreatorEntryGroup({
    required this.label,
    required this.accent,
    required this.emptyMessage,
    required this.entries,
    required this.onOpen,
    required this.onComplete,
    required this.onDelay,
    required this.onSkip,
  });

  final String label;
  final Color accent;
  final String emptyMessage;
  final List<Task> entries;
  final ValueChanged<Task> onOpen;
  final ValueChanged<Task> onComplete;
  final ValueChanged<Task> onDelay;
  final ValueChanged<Task> onSkip;

  @override
  Widget build(BuildContext context) {
    final List<Task> visibleEntries = entries.take(4).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.45),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Text(
                entries.length.toString(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (visibleEntries.isEmpty)
            Text(
              emptyMessage,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                height: 1.3,
              ),
            )
          else
            Column(
              children: visibleEntries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CreatorEntryTile(
                        entry: entry,
                        accent: accent,
                        onOpen: () => onOpen(entry),
                        onComplete: () => onComplete(entry),
                        onDelay: () => onDelay(entry),
                        onSkip: () => onSkip(entry),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _CreatorEntryTile extends StatelessWidget {
  const _CreatorEntryTile({
    required this.entry,
    required this.accent,
    required this.onOpen,
    required this.onComplete,
    required this.onDelay,
    required this.onSkip,
  });

  final Task entry;
  final Color accent;
  final VoidCallback onOpen;
  final VoidCallback onComplete;
  final VoidCallback onDelay;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final String description = entry.description?.trim() ?? '';
    final String kind = (entry.kind ?? 'task').trim().isEmpty
        ? 'task'
        : entry.kind!.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Text(
                kind.toUpperCase(),
                style: TextStyle(
                  color: accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'P${entry.priority}',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              _CreatorTileAction(
                icon: Icons.check,
                tooltip: 'Complete',
                color: Colors.greenAccent,
                onTap: onComplete,
              ),
              const SizedBox(width: 6),
              _CreatorTileAction(
                icon: Icons.schedule,
                tooltip: 'Delay',
                color: AppColors.memoryAmber,
                onTap: onDelay,
              ),
              const SizedBox(width: 6),
              _CreatorTileAction(
                icon: Icons.close,
                tooltip: 'Skip',
                color: AppColors.recallRed,
                onTap: onSkip,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreatorTileAction extends StatelessWidget {
  const _CreatorTileAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}
"@

[System.IO.File]::WriteAllText($entryListsPath, $entryLists, $utf8NoBom)

Write-Host "Formatting changed files..." -ForegroundColor Cyan
dart format $taskModelPath $taskProviderPath $entryListsPath

Write-Host "Applying Dart fixes..." -ForegroundColor Cyan
dart fix --apply $taskModelPath $taskProviderPath $entryListsPath

Write-Host "Formatting again..." -ForegroundColor Cyan
dart format $taskModelPath $taskProviderPath $entryListsPath

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Creator grouped entry lists restored." -ForegroundColor Green
