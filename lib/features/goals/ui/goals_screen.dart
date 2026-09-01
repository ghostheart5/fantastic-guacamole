import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/goal_progress_view.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);

    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgTemporalCalm,
      overlayOpacity: 0.46,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: TemporalScreenHeader(
                  title: 'GOALS',
                  subtitle: 'Direct the next horizon.',
                  eyebrow: '${goals.length} active',
                  accent: AppColors.memoryAmber,
                  onBack: () => goToAppView(context, ref, AppView.smartPlanner),
                  trailing: IconButton(
                    tooltip: 'Add goal',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    onPressed: () async => _showAddSheet(context, ref),
                    icon: const Icon(
                      Icons.add_rounded,
                      color: AppColors.neonCyan,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: goals.isEmpty
                    ? _EmptyGoals(
                        onAdd: () async => _showAddSheet(context, ref),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
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

  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime? targetDate;
    bool isSaving = false;
    String? saveError;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheetState) => AnimatedPadding(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: TemporalGlassSurface(
              accent: AppColors.memoryAmber,
              opacity: 0.96,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Center(
                      child: SizedBox(
                        width: 52,
                        child: Divider(thickness: 3, color: Colors.white38),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'GOALS · NEW DIRECTION',
                      style: TextStyle(
                        color: AppColors.memoryAmber,
                        fontSize: 11,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add a goal',
                      style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Name the future you want to direct.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    _SheetField(controller: titleCtrl, hint: 'Goal title'),
                    const SizedBox(height: 12),
                    _SheetField(
                      controller: descCtrl,
                      hint: 'Description (optional)',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(
                            const Duration(days: 30),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.memoryAmber,
                                onPrimary: Colors.black,
                                surface: Color(0xFF0B111C),
                                onSurface: Colors.white70,
                              ),
                            ),
                            child: child ?? const SizedBox.shrink(),
                          ),
                        );
                        if (picked != null) {
                          setSheetState(() => targetDate = picked);
                        }
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 52),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgSecondary.withValues(alpha: 0.84),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.memoryAmber.withValues(
                              alpha: 0.38,
                            ),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.calendar_month_outlined,
                              color: AppColors.memoryAmber,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                targetDate != null
                                    ? 'Target: ${targetDate!.day}/${targetDate!.month}/${targetDate!.year}'
                                    : 'Set target date (optional)',
                                style: TextStyle(
                                  color: targetDate != null
                                      ? AppColors.memoryAmber
                                      : Colors.white54,
                                  fontSize: 13,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (saveError != null) ...<Widget>[
                      Text(
                        saveError!,
                        style: const TextStyle(
                          color: AppColors.recallRed,
                          fontSize: 12,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const TemporalDivider(color: AppColors.memoryAmber),
                    const SizedBox(height: 16),
                    TemporalActionButton(
                      label: 'ADD GOAL',
                      icon: Icons.add_circle_outline_rounded,
                      accent: AppColors.neonCyan,
                      onPressed: isSaving
                          ? null
                          : () async {
                              final title = titleCtrl.text.trim();
                              if (title.isEmpty) {
                                setSheetState(
                                  () => saveError = 'Enter a goal title first.',
                                );
                                return;
                              }
                              setSheetState(() {
                                isSaving = true;
                                saveError = null;
                              });
                              try {
                                await ref
                                    .read(goalsProvider.notifier)
                                    .add(
                                      title: title,
                                      description: descCtrl.text.trim().isEmpty
                                          ? null
                                          : descCtrl.text.trim(),
                                      targetDate: targetDate,
                                    );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                              } on Object {
                                if (ctx.mounted) {
                                  setSheetState(() {
                                    isSaving = false;
                                    saveError =
                                        'Goal could not be saved. Please try again.';
                                  });
                                }
                              }
                            },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.neonCyan,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: isSaving
                            ? null
                            : () => Navigator.of(ctx).pop(),
                        child: const Text('CANCEL'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      titleCtrl.dispose();
      descCtrl.dispose();
    }
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: TemporalGlassSurface(
            accent: AppColors.memoryAmber,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.track_changes_rounded,
                  size: 48,
                  color: AppColors.memoryAmber,
                ),
                const SizedBox(height: 14),
                const Text(
                  'No goals yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add your first direction and connect tasks as the plan takes shape.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.45,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 18),
                TemporalActionButton(
                  label: 'ADD A GOAL',
                  icon: Icons.add_rounded,
                  onPressed: onAdd,
                ),
              ],
            ),
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

  Future<void> _shareGoal(GoalProgressView goalProgress) async {
    final GoalEntity goal = widget.goal;
    final int total = goalProgress.totalCount;
    final int completed = goalProgress.completedCount;
    final DateTime? targetDate = goal.targetDate;
    final String targetLabel = targetDate == null
        ? 'No target date set'
        : 'Target date: ${targetDate.day}/${targetDate.month}/${targetDate.year}';
    final String text =
        'ChronoSpark Goal\n'
        '${goal.title}\n'
        'Progress: $completed/$total tasks complete\n'
        '$targetLabel\n'
        'Build your goal system: ${AppUrls.website}';

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          title: 'ChronoSpark Goal',
          subject: 'My ChronoSpark goal',
        ),
      );
      AppAnalytics.track(
        'share_goal',
        params: <String, Object?>{'method': 'share_sheet'},
      );
      return;
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      AppAnalytics.track(
        'share_goal',
        params: <String, Object?>{'method': 'clipboard_fallback'},
      );
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Share sheet unavailable. Goal summary copied to clipboard.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goalProgress =
        ref.watch(goalProgressProvider(widget.goal.id)).value ??
        const GoalProgressView.empty();
    final linked = goalProgress.tasks;
    final int total = goalProgress.totalCount;
    final int completed = goalProgress.completedCount;
    final double progress = goalProgress.fraction;

    final now = DateTime.now();
    final targetDate = widget.goal.targetDate;
    final isOverdue = targetDate != null && targetDate.isBefore(now);
    final dateColor = isOverdue ? AppColors.recallRed : AppColors.neonCyan;
    final goalColor = Color(widget.goal.colorHex);

    return Dismissible(
      key: Key(widget.goal.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        ref.read(goalsProvider.notifier).complete(widget.goal.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.recallRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.check_circle_outline,
          color: AppColors.recallRed,
        ),
      ),
      child: TemporalGlassSurface(
        accent: goalColor,
        opacity: 0.9,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 4,
                        height: 48,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: goalColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.goal.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            height: 1.35,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Share goal',
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        onPressed: () => _shareGoal(goalProgress),
                        icon: Icon(
                          Icons.ios_share_rounded,
                          color: goalColor.withValues(alpha: 0.9),
                          size: 20,
                        ),
                      ),
                      IconButton(
                        tooltip: _expanded
                            ? 'Collapse goal details'
                            : 'Expand goal details',
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        onPressed: () => setState(() => _expanded = !_expanded),
                        icon: Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  if (widget.goal.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.goal.description!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                  if (targetDate != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.calendar_month_outlined,
                          color: dateColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Target ${targetDate.day}/${targetDate.month}/${targetDate.year}',
                          style: TextStyle(
                            color: dateColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
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
                        '$completed of $total actions',
                        style: TextStyle(
                          color: goalColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
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
                                    color: Colors.white70,
                                    fontSize: 12,
                                    letterSpacing: 0,
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
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.memoryAmber.withValues(alpha: 0.38),
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white54, letterSpacing: 0),
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
