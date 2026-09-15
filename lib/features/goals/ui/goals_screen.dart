import 'package:fantastic_guacamole/l10n/journey_copy.dart';
import 'package:fantastic_guacamole/ui/widgets/text_controller_scope.dart';
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
    final goalsRead = ref.watch(goalsReadProvider);
    final bool es = Localizations.localeOf(context).languageCode == 'es';

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
                  title: journeyText(context, 'GOALS', 'METAS'),
                  subtitle: journeyText(
                    context,
                    'Direct the next horizon.',
                    'Dirige tu próximo horizonte.',
                  ),
                  eyebrow: journeyText(
                    context,
                    '${goals.length} active',
                    '${goals.length} ${goals.length == 1 ? 'activa' : 'activas'}',
                  ),
                  backTooltip: es ? 'Atrás' : 'Back',
                  accent: AppColors.memoryAmber,
                  onBack: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      goToAppView(context, ref, AppView.nexus);
                    }
                  },
                  trailing: IconButton(
                    tooltip: journeyText(context, 'Add goal', 'Añadir meta'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    onPressed: goalsRead.hasError
                        ? null
                        : () async => _showAddSheet(context, ref),
                    icon: const Icon(
                      Icons.add_rounded,
                      color: AppColors.neonCyan,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: goalsRead.hasError
                    ? Column(
                        children: [
                          Text(
                            es
                                ? 'No se pueden leer tus metas. Los datos existentes se conservaron.'
                                : 'Your goals could not be read. Existing data was preserved.',
                          ),
                          TextButton(
                            onPressed: () => ref.invalidate(goalsReadProvider),
                            child: Text(es ? 'Reintentar' : 'Retry'),
                          ),
                        ],
                      )
                    : goals.isEmpty
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
    DateTime? targetDate;
    bool isSaving = false;
    String? saveError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (ctx) => TextControllerScope(
        initialTexts: const <String>['', ''],
        builder: (ctx, controllers) {
          final titleCtrl = controllers[0];
          final descCtrl = controllers[1];
          return StatefulBuilder(
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
                      Text(
                        journeyText(
                          context,
                          'GOALS · NEW DIRECTION',
                          'METAS · NUEVO RUMBO',
                        ),
                        style: const TextStyle(
                          color: AppColors.memoryAmber,
                          fontSize: 11,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        journeyText(context, 'Add a goal', 'Añadir una meta'),
                        style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        journeyText(
                          context,
                          'Name the future you want to direct.',
                          'Ponle nombre al futuro que quieres construir.',
                        ),
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SheetField(
                        controller: titleCtrl,
                        hint: journeyText(
                          context,
                          'Goal title',
                          'Título de la meta',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SheetField(
                        controller: descCtrl,
                        hint: journeyText(
                          context,
                          'Description (optional)',
                          'Descripción (opcional)',
                        ),
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
                            color: AppColors.bgSecondary.withValues(
                              alpha: 0.84,
                            ),
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
                                      ? journeyText(
                                          context,
                                          'Target: ${targetDate!.day}/${targetDate!.month}/${targetDate!.year}',
                                          'Objetivo: ${targetDate!.day}/${targetDate!.month}/${targetDate!.year}',
                                        )
                                      : journeyText(
                                          context,
                                          'Set target date (optional)',
                                          'Elegir fecha objetivo (opcional)',
                                        ),
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
                        label: journeyText(context, 'ADD GOAL', 'AÑADIR META'),
                        icon: Icons.add_circle_outline_rounded,
                        accent: AppColors.neonCyan,
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (isSaving) return;
                                final title = titleCtrl.text.trim();
                                if (title.isEmpty) {
                                  setSheetState(
                                    () => saveError = journeyText(
                                      context,
                                      'Enter a goal title first.',
                                      'Escribe primero un título para la meta.',
                                    ),
                                  );
                                  return;
                                }
                                setSheetState(() {
                                  isSaving = true;
                                  saveError = null;
                                });
                                try {
                                  final result = await ref
                                      .read(goalsProvider.notifier)
                                      .add(
                                        title: title,
                                        description:
                                            descCtrl.text.trim().isEmpty
                                            ? null
                                            : descCtrl.text.trim(),
                                        targetDate: targetDate,
                                      );
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                  if (context.mounted &&
                                      result.hasWarnings &&
                                      !result.accountChanged) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          journeyText(
                                            context,
                                            'Goal saved. Some reminders or activity updates could not finish.',
                                            'Meta guardada. No se pudieron completar algunos recordatorios o actualizaciones de actividad.',
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                } on Object {
                                  if (ctx.mounted) {
                                    setSheetState(() {
                                      isSaving = false;
                                      saveError = journeyText(
                                        context,
                                        'Goal could not be saved. Please try again.',
                                        'No se pudo guardar la meta. Inténtalo de nuevo.',
                                      );
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
                          child: Text(
                            journeyText(context, 'CANCEL', 'CANCELAR'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
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
                Text(
                  journeyText(context, 'No goals yet', 'Aún no hay metas'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  journeyText(
                    context,
                    'Add your first direction and connect tasks as the plan takes shape.',
                    'Añade tu primer rumbo y vincula tareas a medida que el plan tome forma.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.45,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 18),
                TemporalActionButton(
                  label: journeyText(context, 'ADD A GOAL', 'AÑADIR UNA META'),
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

  Future<void> _editGoal() async {
    final title = TextEditingController(text: widget.goal.title);
    final description = TextEditingController(
      text: widget.goal.description ?? '',
    );
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(journeyText(context, 'Edit goal', 'Editar meta')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              key: const Key('edit-goal-title'),
              controller: title,
              decoration: InputDecoration(
                labelText: journeyText(context, 'Title', 'Título'),
              ),
            ),
            TextField(
              key: const Key('edit-goal-description'),
              controller: description,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: journeyText(context, 'Description', 'Descripción'),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(journeyText(context, 'Cancel', 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(journeyText(context, 'Save', 'Guardar')),
          ),
        ],
      ),
    );
    final String nextTitle = title.text.trim();
    final String nextDescription = description.text.trim();
    title.dispose();
    description.dispose();
    if (save != true || nextTitle.isEmpty || !mounted) return;
    await ref
        .read(goalsProvider.notifier)
        .update(
          widget.goal.copyWith(
            title: nextTitle,
            description: nextDescription.isEmpty ? null : nextDescription,
            clearDescription: nextDescription.isEmpty,
          ),
        );
  }

  Future<void> _deleteGoal() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(journeyText(context, 'Delete goal?', '¿Eliminar meta?')),
        content: Text(
          journeyText(
            context,
            'This permanently removes the goal. Linked tasks remain available.',
            'Esto elimina la meta permanentemente. Las tareas vinculadas permanecen disponibles.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(journeyText(context, 'Cancel', 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(journeyText(context, 'Delete', 'Eliminar')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(goalsProvider.notifier).deletePermanently(widget.goal.id);
    }
  }

  Future<void> _shareGoal(GoalProgressView goalProgress) async {
    final GoalEntity goal = widget.goal;
    final int total = goalProgress.totalCount;
    final int completed = goalProgress.completedCount;
    final DateTime? targetDate = goal.targetDate;
    final String targetLabel = targetDate == null
        ? journeyText(context, 'No target date set', 'Sin fecha objetivo')
        : journeyText(
            context,
            'Target date: ${targetDate.day}/${targetDate.month}/${targetDate.year}',
            'Fecha objetivo: ${targetDate.day}/${targetDate.month}/${targetDate.year}',
          );
    final String text = journeyText(
      context,
      'ChronoSpark Goal\n'
          '${goal.title}\n'
          'One-time actions: $completed/$total complete\n'
          'Recurring completions: ${goalProgress.recurringCompletedCount}\n'
          '$targetLabel\n'
          'Build your goal system: ${AppUrls.website}',
      'Meta de ChronoSpark\n${goal.title}\nAcciones únicas: $completed/$total completadas\nRepeticiones completadas: ${goalProgress.recurringCompletedCount}\n$targetLabel\nConstruye tu sistema de metas: ${AppUrls.website}',
    );

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          title: journeyText(
            context,
            'ChronoSpark Goal',
            'Meta de ChronoSpark',
          ),
          subject: journeyText(
            context,
            'My ChronoSpark goal',
            'Mi meta de ChronoSpark',
          ),
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
      SnackBar(
        content: Text(
          journeyText(
            context,
            'Share sheet unavailable. Goal summary copied to clipboard.',
            'No se puede abrir el menú para compartir. Resumen de la meta copiado al portapapeles.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progressRead = ref.watch(goalProgressProvider(widget.goal.id));
    final goalProgress =
        progressRead.asData?.value ?? const GoalProgressView.empty();
    final bool es = Localizations.localeOf(context).languageCode == 'es';
    final linked = goalProgress.tasks;
    final int total = goalProgress.totalCount;
    final int completed = goalProgress.completedCount;
    final double progress = goalProgress.fraction;

    final now = DateTime.now().toLocal();
    final targetDate = widget.goal.targetDate;
    final localTarget = targetDate?.toLocal();
    final isOverdue =
        localTarget != null &&
        DateTime(
          localTarget.year,
          localTarget.month,
          localTarget.day,
        ).isBefore(DateTime(now.year, now.month, now.day));
    final dateColor = isOverdue ? AppColors.recallRed : AppColors.neonCyan;
    final goalColor = Color(widget.goal.colorHex);

    return Dismissible(
      key: Key(widget.goal.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        try {
          final result = await ref
              .read(goalsProvider.notifier)
              .complete(widget.goal.id);
          if (context.mounted && result.hasWarnings && !result.accountChanged) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  journeyText(
                    context,
                    'Goal completed. Some reminders or activity updates could not finish.',
                    'Meta completada. No se pudieron completar algunos recordatorios o actualizaciones de actividad.',
                  ),
                ),
              ),
            );
          }
          return true;
        } on Object {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  journeyText(
                    context,
                    'Goal could not be completed. Please try again.',
                    'No se pudo completar la meta. Inténtalo de nuevo.',
                  ),
                ),
              ),
            );
          }
          return false;
        }
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
      child: Semantics(
        container: true,
        explicitChildNodes: true,
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
                        PopupMenuButton<String>(
                          tooltip: journeyText(
                            context,
                            'Manage goal',
                            'Administrar meta',
                          ),
                          onSelected: (value) async {
                            if (value == 'edit') await _editGoal();
                            if (value == 'delete') await _deleteGoal();
                          },
                          itemBuilder: (_) => <PopupMenuEntry<String>>[
                            PopupMenuItem(
                              value: 'edit',
                              child: Text(
                                journeyText(
                                  context,
                                  'Edit goal',
                                  'Editar meta',
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                journeyText(
                                  context,
                                  'Delete goal',
                                  'Eliminar meta',
                                ),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          tooltip: journeyText(
                            context,
                            'Share goal: ${widget.goal.title}',
                            'Compartir meta: ${widget.goal.title}',
                          ),
                          constraints: const BoxConstraints.tightFor(
                            width: 48,
                            height: 48,
                          ),
                          onPressed:
                              progressRead.isLoading || progressRead.hasError
                              ? null
                              : () => _shareGoal(goalProgress),
                          icon: Icon(
                            Icons.ios_share_rounded,
                            color: goalColor.withValues(alpha: 0.9),
                            size: 20,
                          ),
                        ),
                        IconButton(
                          tooltip: _expanded
                              ? journeyText(
                                  context,
                                  'Collapse goal details: ${widget.goal.title}',
                                  'Contraer detalles de la meta: ${widget.goal.title}',
                                )
                              : journeyText(
                                  context,
                                  'Expand goal details: ${widget.goal.title}',
                                  'Expandir detalles de la meta: ${widget.goal.title}',
                                ),
                          constraints: const BoxConstraints.tightFor(
                            width: 48,
                            height: 48,
                          ),
                          onPressed: () =>
                              setState(() => _expanded = !_expanded),
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
                            journeyText(
                              context,
                              'Target ${targetDate.day}/${targetDate.month}/${targetDate.year}',
                              'Objetivo ${targetDate.day}/${targetDate.month}/${targetDate.year}',
                            ),
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
                    if (progressRead.isLoading)
                      Text(es ? 'Cargando progreso…' : 'Loading progress…')
                    else if (progressRead.hasError)
                      TextButton(
                        onPressed: () => ref.invalidate(
                          goalProgressProvider(widget.goal.id),
                        ),
                        child: Text(
                          es
                              ? 'Progreso no disponible. Reintentar'
                              : 'Progress unavailable. Retry',
                        ),
                      )
                    else
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
                            es
                                ? '$completed de $total acciones únicas'
                                : '$completed of $total one-time actions',
                            style: TextStyle(
                              color: goalColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    if (!progressRead.isLoading &&
                        !progressRead.hasError &&
                        total > 0 &&
                        completed == total) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        journeyText(
                          context,
                          'All linked actions are complete. This goal stays active until you mark the goal complete.',
                          'Todas las acciones vinculadas están completas. La meta sigue activa hasta que la marques como completada.',
                        ),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (!progressRead.isLoading &&
                        !progressRead.hasError &&
                        (goalProgress.recurringCompletedCount > 0 ||
                            goalProgress.excludedCount > 0))
                      Text(
                        es
                            ? '${goalProgress.recurringCompletedCount} repeticiones completadas; ${goalProgress.excludedCount} acciones omitidas o canceladas fuera del porcentaje.'
                            : '${goalProgress.recurringCompletedCount} recurring completions; ${goalProgress.excludedCount} skipped or canceled actions excluded from the ratio.',
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
