import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/settings_bg.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.memoryAmber,
          foregroundColor: Colors.black,
          onPressed: () => _showAddSheet(context, ref),
          child: const Icon(Icons.add, size: 22),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => ref.read(appFlowProvider.notifier).toCoach(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.memoryAmber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.memoryAmber.withValues(alpha: 0.3),
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
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.memoryAmber, AppColors.neonCyan],
                          ).createShader(bounds),
                          child: const Text(
                            'GOALS',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Text(
                          'YOUR MISSIONS',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: goals.isEmpty
                    ? const Center(
                        child: Text(
                          'No goals yet.\nAdd your first mission.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        itemCount: goals.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) => _GoalCard(goal: goals[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime? targetDate;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B111C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NEW GOAL',
                style: TextStyle(
                  color: AppColors.memoryAmber,
                  fontSize: 11,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              _SheetField(controller: titleCtrl, hint: 'Goal title'),
              const SizedBox(height: 10),
              _SheetField(
                controller: descCtrl,
                hint: 'Description (optional)',
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: AppColors.memoryAmber,
                          onPrimary: Colors.black,
                          surface: Color(0xFF0B111C),
                          onSurface: Colors.white70,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setSheetState(() => targetDate = picked);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.memoryAmber.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    targetDate != null
                        ? 'Target: ${targetDate!.day}/${targetDate!.month}/${targetDate!.year}'
                        : 'Set target date (optional)',
                    style: TextStyle(
                      color: targetDate != null
                          ? AppColors.memoryAmber
                          : Colors.white24,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.memoryAmber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;
                    ref
                        .read(goalsProvider.notifier)
                        .add(
                          title: title,
                          description: descCtrl.text.trim().isEmpty
                              ? null
                              : descCtrl.text.trim(),
                          targetDate: targetDate,
                        );
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'ADD GOAL',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
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

class _GoalCard extends ConsumerStatefulWidget {
  const _GoalCard({required this.goal});
  final GoalEntity goal;

  @override
  ConsumerState<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends ConsumerState<_GoalCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider).asData?.value ?? [];
    final linked = tasks.where((t) => t.goalId == widget.goal.id).toList();
    final total = linked.length;
    final progress = total > 0 ? linked.length / total : 0.0;

    final now = DateTime.now();
    final targetDate = widget.goal.targetDate;
    final isOverdue = targetDate != null && targetDate.isBefore(now);
    final dateColor = isOverdue ? AppColors.recallRed : AppColors.neonCyan;
    final goalColor = Color(widget.goal.colorHex);

    return Dismissible(
      key: Key(widget.goal.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        ref.read(goalsProvider.notifier).remove(widget.goal.id);
        ref
            .read(timelineProvider.notifier)
            .record(
              TimelineEventEntity(
                id: 'gc_${widget.goal.id}_${DateTime.now().millisecondsSinceEpoch}',
                type: TimelineEventType.goalComplete,
                title: 'Goal completed',
                detail: widget.goal.title,
                timestamp: DateTime.now(),
              ),
            );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.recallRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.check_circle_outline,
          color: AppColors.recallRed,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF050D1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: goalColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.goal.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (targetDate != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: dateColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: dateColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '${targetDate.day}/${targetDate.month}/${targetDate.year}',
                            style: TextStyle(
                              color: dateColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white38,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  if (widget.goal.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.goal.description!,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              goalColor,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$total tasks',
                        style: TextStyle(
                          color: goalColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_expanded && linked.isNotEmpty) ...[
              Divider(color: goalColor.withValues(alpha: 0.15), height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: linked
                      .map(
                        (t) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Icon(
                                Icons.radio_button_unchecked,
                                size: 12,
                                color: goalColor.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  t.title,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.memoryAmber.withValues(alpha: 0.25),
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
