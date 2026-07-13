import 'package:fantastic_guacamole/core/utils/date_time_formats.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _MilestoneFilter { all, active, completed, overdue, upcoming, archived }

enum _MilestoneSort { priority, dueDate, progress, updated }

class MilestonesScreen extends ConsumerStatefulWidget {
  const MilestonesScreen({super.key});

  @override
  ConsumerState<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends ConsumerState<MilestonesScreen> {
  String _query = '';
  _MilestoneFilter _filter = _MilestoneFilter.active;
  _MilestoneSort _sort = _MilestoneSort.priority;
  MilestoneCategory? _category;

  Future<void> _openCreate() async {
    final _MilestoneDraft? draft = await showModalBottomSheet<_MilestoneDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF07111D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _MilestoneEditorSheet(),
    );
    if (draft == null) {
      return;
    }
    await ref
        .read(milestoneActionsProvider)
        .createMilestone(
          title: draft.title,
          description: draft.description,
          goalId: draft.goalId,
          projectId: draft.projectId,
          habitId: draft.habitId,
          category: draft.category,
          priority: draft.priority,
          targetDate: draft.targetDate,
          reward: draft.reward,
          note: draft.note,
          reminderAt: draft.reminderAt,
          dependencies: draft.dependencies,
        );
  }

  Future<void> _openEdit(MilestoneEntity milestone) async {
    final _MilestoneDraft? draft = await showModalBottomSheet<_MilestoneDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF07111D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MilestoneEditorSheet(existing: milestone),
    );
    if (draft == null) {
      return;
    }
    await ref
        .read(milestonesProvider.notifier)
        .updateMilestone(
          milestone.copyWith(
            title: draft.title,
            description: draft.description,
            goalId: draft.goalId,
            projectId: draft.projectId,
            habitId: draft.habitId,
            category: draft.category,
            priority: draft.priority,
            targetDate: draft.targetDate,
            reward: draft.reward,
            note: draft.note,
            reminderAt: draft.reminderAt,
            dependencies: draft.dependencies,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<MilestoneEntity>> milestonesAsync = ref.watch(
      milestonesProvider,
    );
    final MilestoneSummary summary = ref.watch(milestoneSummaryProvider);

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/progression_bg.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.memoryAmber,
          foregroundColor: const Color(0xFF061019),
          onPressed: _openCreate,
          icon: const Icon(Icons.flag_rounded),
          label: const Text(
            'NEW MILESTONE',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.7),
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Row(
                  children: [
                    SmartPressable(
                      onTap: () =>
                          ref.read(appFlowProvider.notifier).toSmartCoach(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.memoryAmber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.memoryAmber.withValues(
                              alpha: 0.28,
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.memoryAmber,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (Rect bounds) => const LinearGradient(
                            colors: [AppColors.memoryAmber, AppColors.neonCyan],
                          ).createShader(bounds),
                          child: const Text(
                            'MILESTONES',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.6,
                            ),
                          ),
                        ),
                        const Text(
                          'CHECKPOINT OPERATIONS',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.8,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    PopupMenuButton<_MilestoneSort>(
                      initialValue: _sort,
                      onSelected: (_MilestoneSort value) =>
                          setState(() => _sort = value),
                      color: const Color(0xFF0B1526),
                      itemBuilder: (BuildContext context) => _MilestoneSort
                          .values
                          .map(
                            (_MilestoneSort value) =>
                                PopupMenuItem<_MilestoneSort>(
                                  value: value,
                                  child: Text(
                                    _sortLabel(value),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                          )
                          .toList(growable: false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.sort_rounded,
                              size: 16,
                              color: Colors.white70,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'SORT',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: _MilestoneSummaryStrip(summary: summary),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: TextField(
                  onChanged: (String value) => setState(() => _query = value),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search milestones, notes, or reflections...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white38,
                    ),
                    filled: true,
                    fillColor: const Color(0xAA091427),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.memoryAmber.withValues(alpha: 0.25),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.neonCyan),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _MilestoneFilter.values
                        .map(
                          (_MilestoneFilter filter) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _FilterChip(
                              label: _filterLabel(filter),
                              selected: _filter == filter,
                              onTap: () => setState(() => _filter = filter),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All Categories',
                        selected: _category == null,
                        onTap: () => setState(() => _category = null),
                      ),
                      const SizedBox(width: 8),
                      ...MilestoneCategory.values.map(
                        (MilestoneCategory category) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: _categoryLabel(category),
                            selected: _category == category,
                            onTap: () => setState(() => _category = category),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: milestonesAsync.when(
                  data: (List<MilestoneEntity> milestones) {
                    final List<MilestoneEntity> filtered =
                        milestones
                            .where((MilestoneEntity item) {
                              final String q = _query.trim().toLowerCase();
                              if (q.isNotEmpty) {
                                final bool matches =
                                    item.title.toLowerCase().contains(q) ||
                                    (item.description?.toLowerCase().contains(
                                          q,
                                        ) ??
                                        false) ||
                                    (item.note?.toLowerCase().contains(q) ??
                                        false) ||
                                    (item.reflection?.toLowerCase().contains(
                                          q,
                                        ) ??
                                        false);
                                if (!matches) {
                                  return false;
                                }
                              }
                              if (_category != null &&
                                  item.category != _category) {
                                return false;
                              }
                              return switch (_filter) {
                                _MilestoneFilter.all => true,
                                _MilestoneFilter.active => item.isActive,
                                _MilestoneFilter.completed => item.isCompleted,
                                _MilestoneFilter.overdue => item.isOverdue,
                                _MilestoneFilter.upcoming => item.isUpcoming,
                                _MilestoneFilter.archived => item.isArchived,
                              };
                            })
                            .toList(growable: false)
                          ..sort((MilestoneEntity a, MilestoneEntity b) {
                            return switch (_sort) {
                              _MilestoneSort.priority =>
                                b.priority.index.compareTo(a.priority.index),
                              _MilestoneSort.dueDate =>
                                (a.targetDate ?? DateTime(2100)).compareTo(
                                  b.targetDate ?? DateTime(2100),
                                ),
                              _MilestoneSort.progress =>
                                b.completionPercent.compareTo(
                                  a.completionPercent,
                                ),
                              _MilestoneSort.updated => b.updatedAt.compareTo(
                                a.updatedAt,
                              ),
                            };
                          });

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                          'No milestones match this filter.',
                          style: TextStyle(color: Colors.white38),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, int index) => _MilestoneCard(
                        milestone: filtered[index],
                        onEdit: () => _openEdit(filtered[index]),
                        onAdjustProgress: (double nextProgress) {
                          ref
                              .read(milestoneActionsProvider)
                              .updateProgress(filtered[index].id, nextProgress);
                        },
                        onComplete: () => ref
                            .read(milestoneActionsProvider)
                            .complete(filtered[index].id),
                        onArchive: () => ref
                            .read(milestoneActionsProvider)
                            .archive(filtered[index].id),
                        onDelete: () => ref
                            .read(milestoneActionsProvider)
                            .remove(filtered[index].id),
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.neonCyan),
                  ),
                  error: (_, _) => const Center(
                    child: Text(
                      'Failed to load milestones.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MilestoneSummaryStrip extends StatelessWidget {
  const _MilestoneSummaryStrip({required this.summary});

  final MilestoneSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xAA07111F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.memoryAmber.withValues(alpha: 0.24),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatPill(label: 'TOTAL', value: '${summary.total}'),
          _StatPill(label: 'ACTIVE', value: '${summary.active}'),
          _StatPill(label: 'DONE', value: '${summary.completed}'),
          _StatPill(label: 'OVERDUE', value: '${summary.overdue}'),
          _StatPill(label: 'UPCOMING', value: '${summary.upcoming}'),
          _StatPill(label: 'HEALTH', value: '${summary.healthScore}%'),
          _StatPill(label: 'MOMENTUM', value: '${summary.momentumScore}%'),
          _StatPill(label: 'RISK', value: '${summary.riskScore}%'),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({
    required this.milestone,
    required this.onEdit,
    required this.onAdjustProgress,
    required this.onComplete,
    required this.onArchive,
    required this.onDelete,
  });

  final MilestoneEntity milestone;
  final VoidCallback onEdit;
  final ValueChanged<double> onAdjustProgress;
  final VoidCallback onComplete;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Color categoryColor = _categoryColor(milestone.category);
    final Color priorityColor = _priorityColor(milestone.priority);
    final DateTime? due = milestone.targetDate;
    final String dueLabel = due == null
        ? 'No due date'
        : DateTimeFormats.dateShort(due);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF071325),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: milestone.isOverdue
              ? AppColors.recallRed.withValues(alpha: 0.45)
              : categoryColor.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      milestone.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (milestone.description?.trim().isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          milestone.description!,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: const Color(0xFF0B1526),
                onSelected: (String value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'complete':
                      onComplete();
                    case 'archive':
                      onArchive();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Text(
                      'Edit',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'complete',
                    child: Text(
                      'Complete',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'archive',
                    child: Text(
                      'Archive',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Tag(
                label: _categoryLabel(milestone.category),
                color: categoryColor,
              ),
              _Tag(
                label: _priorityLabel(milestone.priority),
                color: priorityColor,
              ),
              _Tag(
                label: milestone.isOverdue
                    ? 'OVERDUE'
                    : milestone.status.name.toUpperCase(),
                color: milestone.isOverdue
                    ? AppColors.recallRed
                    : Colors.white54,
              ),
              _Tag(
                label: 'Due: $dueLabel',
                color: milestone.isOverdue
                    ? AppColors.recallRed
                    : Colors.white54,
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            minHeight: 6,
            value: (milestone.completionPercent / 100).clamp(0, 1),
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${milestone.completionPercent.round()}% complete',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => onAdjustProgress(
                  (milestone.completionPercent - 10).clamp(0, 100),
                ),
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.white60,
                  size: 18,
                ),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                onPressed: () => onAdjustProgress(
                  (milestone.completionPercent + 10).clamp(0, 100),
                ),
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.neonCyan,
                  size: 18,
                ),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SmartPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.memoryAmber.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.memoryAmber.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.memoryAmber : Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _MilestoneEditorSheet extends StatefulWidget {
  const _MilestoneEditorSheet({this.existing});

  final MilestoneEntity? existing;

  @override
  State<_MilestoneEditorSheet> createState() => _MilestoneEditorSheetState();
}

class _MilestoneEditorSheetState extends State<_MilestoneEditorSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _goalCtrl;
  late final TextEditingController _projectCtrl;
  late final TextEditingController _habitCtrl;
  late final TextEditingController _rewardCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _dependenciesCtrl;

  late MilestoneCategory _category;
  late MilestonePriority _priority;
  DateTime? _targetDate;
  DateTime? _reminderAt;

  @override
  void initState() {
    super.initState();
    final MilestoneEntity? existing = widget.existing;
    _titleCtrl = TextEditingController(text: existing?.title ?? '');
    _descriptionCtrl = TextEditingController(text: existing?.description ?? '');
    _goalCtrl = TextEditingController(text: existing?.goalId ?? '');
    _projectCtrl = TextEditingController(text: existing?.projectId ?? '');
    _habitCtrl = TextEditingController(text: existing?.habitId ?? '');
    _rewardCtrl = TextEditingController(text: existing?.reward ?? '');
    _noteCtrl = TextEditingController(text: existing?.note ?? '');
    _dependenciesCtrl = TextEditingController(
      text: (existing?.dependencies ?? const <String>[]).join(', '),
    );
    _category = existing?.category ?? MilestoneCategory.goal;
    _priority = existing?.priority ?? MilestonePriority.medium;
    _targetDate = existing?.targetDate;
    _reminderAt = existing?.reminderAt;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _goalCtrl.dispose();
    _projectCtrl.dispose();
    _habitCtrl.dispose();
    _rewardCtrl.dispose();
    _noteCtrl.dispose();
    _dependenciesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing == null ? 'NEW MILESTONE' : 'EDIT MILESTONE',
              style: const TextStyle(
                color: AppColors.memoryAmber,
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _SheetField(controller: _titleCtrl, hint: 'Title'),
            const SizedBox(height: 8),
            _SheetField(
              controller: _descriptionCtrl,
              hint: 'Description',
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SheetField(
                    controller: _goalCtrl,
                    hint: 'Goal ID (optional)',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SheetField(
                    controller: _projectCtrl,
                    hint: 'Project ID (optional)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SheetField(
                    controller: _habitCtrl,
                    hint: 'Habit ID (optional)',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SheetField(
                    controller: _rewardCtrl,
                    hint: 'Reward (optional)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _SheetField(
              controller: _noteCtrl,
              hint: 'Note (optional)',
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            _SheetField(
              controller: _dependenciesCtrl,
              hint: 'Dependencies (comma separated)',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DropDownField<MilestoneCategory>(
                    value: _category,
                    values: MilestoneCategory.values,
                    labelBuilder: _categoryLabel,
                    onChanged: (MilestoneCategory? value) {
                      if (value != null) {
                        setState(() => _category = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DropDownField<MilestonePriority>(
                    value: _priority,
                    values: MilestonePriority.values,
                    labelBuilder: _priorityLabel,
                    onChanged: (MilestonePriority? value) {
                      if (value != null) {
                        setState(() => _priority = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: _targetDate == null
                        ? 'Set target date'
                        : 'Target ${DateTimeFormats.dateShort(_targetDate!)}',
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate:
                            _targetDate ??
                            DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                      );
                      if (picked != null) {
                        setState(() => _targetDate = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DateButton(
                    label: _reminderAt == null
                        ? 'Set reminder date'
                        : 'Reminder ${DateTimeFormats.dateShort(_reminderAt!)}',
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate:
                            _reminderAt ??
                            DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                      );
                      if (picked != null) {
                        setState(() => _reminderAt = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.memoryAmber,
                  foregroundColor: const Color(0xFF041018),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  final String title = _titleCtrl.text.trim();
                  if (title.isEmpty) {
                    return;
                  }
                  final List<String> dependencies = _dependenciesCtrl.text
                      .split(',')
                      .map((String item) => item.trim())
                      .where((String item) => item.isNotEmpty)
                      .toList(growable: false);
                  Navigator.of(context).pop(
                    _MilestoneDraft(
                      title: title,
                      description: _descriptionCtrl.text.trim().isEmpty
                          ? null
                          : _descriptionCtrl.text.trim(),
                      goalId: _goalCtrl.text.trim().isEmpty
                          ? null
                          : _goalCtrl.text.trim(),
                      projectId: _projectCtrl.text.trim().isEmpty
                          ? null
                          : _projectCtrl.text.trim(),
                      habitId: _habitCtrl.text.trim().isEmpty
                          ? null
                          : _habitCtrl.text.trim(),
                      category: _category,
                      priority: _priority,
                      targetDate: _targetDate,
                      reward: _rewardCtrl.text.trim().isEmpty
                          ? null
                          : _rewardCtrl.text.trim(),
                      note: _noteCtrl.text.trim().isEmpty
                          ? null
                          : _noteCtrl.text.trim(),
                      reminderAt: _reminderAt,
                      dependencies: dependencies,
                    ),
                  );
                },
                child: Text(
                  widget.existing == null
                      ? 'CREATE MILESTONE'
                      : 'SAVE MILESTONE',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
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

class _DropDownField<T> extends StatelessWidget {
  const _DropDownField({
    required this.value,
    required this.values,
    required this.labelBuilder,
    required this.onChanged,
  });

  final T value;
  final List<T> values;
  final String Function(T value) labelBuilder;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      dropdownColor: const Color(0xFF0B1526),
      style: const TextStyle(color: Colors.white),
      items: values
          .map(
            (T item) => DropdownMenuItem<T>(
              value: item,
              child: Text(labelBuilder(item)),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SmartPressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
      ),
    );
  }
}

class _MilestoneDraft {
  const _MilestoneDraft({
    required this.title,
    this.description,
    this.goalId,
    this.projectId,
    this.habitId,
    required this.category,
    required this.priority,
    this.targetDate,
    this.reward,
    this.note,
    this.reminderAt,
    this.dependencies = const <String>[],
  });

  final String title;
  final String? description;
  final String? goalId;
  final String? projectId;
  final String? habitId;
  final MilestoneCategory category;
  final MilestonePriority priority;
  final DateTime? targetDate;
  final String? reward;
  final String? note;
  final DateTime? reminderAt;
  final List<String> dependencies;
}

String _filterLabel(_MilestoneFilter value) {
  return switch (value) {
    _MilestoneFilter.all => 'All',
    _MilestoneFilter.active => 'Active',
    _MilestoneFilter.completed => 'Completed',
    _MilestoneFilter.overdue => 'Overdue',
    _MilestoneFilter.upcoming => 'Upcoming',
    _MilestoneFilter.archived => 'Archived',
  };
}

String _sortLabel(_MilestoneSort value) {
  return switch (value) {
    _MilestoneSort.priority => 'Priority',
    _MilestoneSort.dueDate => 'Due Date',
    _MilestoneSort.progress => 'Progress',
    _MilestoneSort.updated => 'Updated',
  };
}

String _categoryLabel(MilestoneCategory value) {
  return switch (value) {
    MilestoneCategory.goal => 'Goal',
    MilestoneCategory.project => 'Project',
    MilestoneCategory.habit => 'Habit',
    MilestoneCategory.streak => 'Streak',
    MilestoneCategory.timeline => 'Timeline',
    MilestoneCategory.financial => 'Financial',
    MilestoneCategory.health => 'Health',
    MilestoneCategory.learning => 'Learning',
    MilestoneCategory.life => 'Life',
    MilestoneCategory.futureSelf => 'Future Self',
    MilestoneCategory.other => 'Other',
  };
}

String _priorityLabel(MilestonePriority value) {
  return switch (value) {
    MilestonePriority.low => 'Low',
    MilestonePriority.medium => 'Medium',
    MilestonePriority.high => 'High',
    MilestonePriority.critical => 'Critical',
  };
}

Color _categoryColor(MilestoneCategory value) {
  return switch (value) {
    MilestoneCategory.goal => const Color(0xFF7AF7C4),
    MilestoneCategory.project => AppColors.neonCyan,
    MilestoneCategory.habit => const Color(0xFFFFB86B),
    MilestoneCategory.streak => const Color(0xFFFF8A65),
    MilestoneCategory.timeline => const Color(0xFF9DB4FF),
    MilestoneCategory.financial => const Color(0xFFFFD166),
    MilestoneCategory.health => const Color(0xFF78FFB8),
    MilestoneCategory.learning => const Color(0xFFC9A3FF),
    MilestoneCategory.life => const Color(0xFFA7B4C8),
    MilestoneCategory.futureSelf => const Color(0xFFB3F0FF),
    MilestoneCategory.other => Colors.white70,
  };
}

Color _priorityColor(MilestonePriority value) {
  return switch (value) {
    MilestonePriority.low => Colors.white54,
    MilestonePriority.medium => AppColors.neonCyan,
    MilestonePriority.high => AppColors.memoryAmber,
    MilestonePriority.critical => AppColors.recallRed,
  };
}
