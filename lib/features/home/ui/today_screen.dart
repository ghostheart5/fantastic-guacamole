import 'dart:async';

import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/features/creator/ui/daily_rhythms_screen.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/tasks/widgets/task_edit_dialog.dart';
import 'package:fantastic_guacamole/l10n/journey_copy.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/features/creator/ui/open_creator.dart';
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A small daily surface over the existing task/goal/habit and intelligence
/// systems. Recommendations never filter the user's commitments out of view.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  final Set<String> _busy = <String>{};
  Timer? _dayTimer;

  String _t(String en, String es) => journeyText(context, en, es);

  @override
  void initState() {
    super.initState();
    _dayTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(allTasksProvider);
    final scope = ref.watch(accountStorageScopeProvider);
    final boundary = ref.watch(authSessionBoundaryProvider);
    final canWrite =
        scope.isWritable &&
        boundary.isStorageReady &&
        !boundary.isTransitioning &&
        boundary.blockingIssue == null;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _t('Today', 'Hoy'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: _t('Notifications', 'Notificaciones'),
                  onPressed: () => context.push(
                    ref.read(routeSurfaceProvider).notifications,
                  ),
                  icon: const Icon(Icons.notifications_outlined),
                ),
                IconButton(
                  tooltip: _t('Settings', 'Ajustes'),
                  onPressed: () => goToAppView(context, ref, AppView.settings),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _t('One thing at a time.', 'Una cosa a la vez.'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              _t(
                'Add what matters. Take a step when you’re ready.',
                'Añade lo que importa. Da un paso cuando quieras.',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('today-add'),
              onPressed: _chooseKind,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                _t(
                  'Add a goal, task or habit',
                  'Añadir una meta, tarea o hábito',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _t('A place to start', 'Por dónde empezar'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            tasks.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(
                      'Your tasks could not load. Try again to see your plan.',
                      'No se pudieron cargar tus tareas. Reintenta para ver tu plan.',
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(allTasksProvider),
                    child: Text(_t('Try again', 'Reintentar')),
                  ),
                ],
              ),
              data: (items) {
                final now = DateTime.now();
                final tomorrow = DateTime(now.year, now.month, now.day + 1);
                final available =
                    items
                        .where(
                          (task) =>
                              task.isActive &&
                              (task.scheduledFor == null ||
                                  (task.dueDate?.toLocal().isBefore(tomorrow) ??
                                      false) ||
                                  task.scheduledFor!.toLocal().isBefore(
                                    tomorrow,
                                  )),
                        )
                        .toList()
                      ..sort((a, b) {
                        final aDate = a.dueDate ?? a.scheduledFor;
                        final bDate = b.dueDate ?? b.scheduledFor;
                        if (aDate == null && bDate != null) return 1;
                        if (bDate == null && aDate != null) return -1;
                        final order = aDate == null
                            ? 0
                            : aDate.compareTo(bDate!);
                        if (order != 0) return order;
                        final created = a.createdAt.compareTo(b.createdAt);
                        return created != 0 ? created : a.id.compareTo(b.id);
                      });
                return Column(
                  children: [
                    if (available.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          _t(
                            items.any((task) => task.isActive)
                                ? 'Your scheduled tasks are ahead. Your full plan is ready when you need it.'
                                : 'No tasks waiting right now. Add something when you want to, or check your history in My plan.',
                            items.any((task) => task.isActive)
                                ? 'Tus tareas est\u00e1n programadas para m\u00e1s adelante. Tu plan completo sigue disponible.'
                                : 'No hay tareas pendientes ahora. A\u00f1ade algo cuando quieras o consulta tu historial en Mi plan.',
                          ),
                        ),
                      ),
                    for (final task in available.take(3))
                      Card(
                        child: ListTile(
                          key: ValueKey('today-task-${task.id}'),
                          contentPadding: const EdgeInsetsDirectional.only(
                            start: 16,
                            end: 4,
                          ),
                          title: Text(task.title),
                          subtitle: task.dueDate == null
                              ? null
                              : Text(
                                  _t('Due ', 'Vence ') +
                                      MaterialLocalizations.of(
                                        context,
                                      ).formatMediumDate(
                                        task.dueDate!.toLocal(),
                                      ),
                                ),
                          onTap: canWrite ? () => _edit(task) : null,
                          trailing: IconButton(
                            key: ValueKey('today-complete-${task.id}'),
                            tooltip:
                                _t('Complete: ', 'Completar: ') + task.title,
                            onPressed: !canWrite || _busy.contains(task.id)
                                ? null
                                : () => _complete(task.id),
                            icon: _busy.contains(task.id)
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.radio_button_unchecked_rounded,
                                  ),
                          ),
                        ),
                      ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () =>
                            goToAppView(context, ref, AppView.timeline),
                        child: Text(
                          _t('See my full plan', 'Ver mi plan completo'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => goToAppView(context, ref, AppView.goals),
                  icon: const Icon(Icons.flag_outlined),
                  label: Text(_t('Goals', 'Metas')),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const DailyRhythmsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.repeat_rounded),
                  label: Text(
                    _t('Check in with a habit', 'Registrar un hábito'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                key: const Key('today-chat'),
                leading: const Icon(Icons.chat_bubble_outline_rounded),
                title: Text(_t('Talk it through', 'Hablarlo')),
                subtitle: Text(
                  _t(
                    'AI and SI help with your thoughts and plans.',
                    'Ayuda de IA y SI para tus ideas y planes.',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => goToAppView(context, ref, AppView.console),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                key: const Key('today-insights'),
                leading: const Icon(Icons.insights_outlined),
                title: Text(
                  _t(
                    'Patterns & future outcomes',
                    'Patrones y resultados futuros',
                  ),
                ),
                subtitle: Text(
                  _t(
                    'See what’s changing and explore what could happen next.',
                    'Ve qué cambia y explora lo que podría pasar después.',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    goToAppView(context, ref, AppView.trajectoryEngine),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => const NexusScreen(showDetails: true),
                ),
              ),
              child: Text(
                _t('Review my day in detail', 'Revisar mi día en detalle'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseKind() async {
    final kind = await showModalBottomSheet<CreatorFormKind>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in [
                  (
                    CreatorFormKind.task,
                    Icons.check_circle_outline,
                    _t('Task', 'Tarea'),
                    _t('Something to do once', 'Algo para hacer una vez'),
                  ),
                  (
                    CreatorFormKind.goal,
                    Icons.flag_outlined,
                    _t('Goal', 'Meta'),
                    _t('Something to work toward', 'Algo que quieres alcanzar'),
                  ),
                  (
                    CreatorFormKind.habit,
                    Icons.repeat_rounded,
                    _t('Habit', 'Hábito'),
                    _t('Something to repeat', 'Algo para repetir'),
                  ),
                  (
                    CreatorFormKind.note,
                    Icons.notes_rounded,
                    _t('Note', 'Nota'),
                    _t(
                      'Something to get off your mind',
                      'Algo que quieres anotar',
                    ),
                  ),
                ])
                  ListTile(
                    key: ValueKey('today-add-${entry.$1.name}'),
                    leading: Icon(entry.$2),
                    title: Text(entry.$3),
                    subtitle: Text(entry.$4),
                    onTap: () => Navigator.pop(sheet, entry.$1),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || kind == null) return;
    await openCreatorForItem(context, ref, kind);
  }

  bool _sameAccount(int generation, String? namespace) =>
      mounted &&
      ref.read(authSessionBoundaryProvider).generation == generation &&
      ref.read(accountStorageScopeProvider).isWritable &&
      ref.read(authSessionBoundaryProvider).isStorageReady &&
      !ref.read(authSessionBoundaryProvider).isTransitioning &&
      ref.read(authSessionBoundaryProvider).blockingIssue == null &&
      ref.read(accountStorageScopeProvider).v2Namespace == namespace;

  Future<void> _complete(String id) async {
    if (_busy.contains(id)) return;
    final generation = ref.read(authSessionBoundaryProvider).generation;
    final namespace = ref.read(accountStorageScopeProvider).v2Namespace;
    if (!_sameAccount(generation, namespace)) return;
    setState(() => _busy.add(id));
    try {
      await ref.read(taskActionsProvider).completeTask(id, notify: false);
      if (mounted && _sameAccount(generation, namespace)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Completed. Your progress is recorded.',
                'Completada. Tu progreso quedó registrado.',
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted && _sameAccount(generation, namespace)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Could not complete this task. Please try again.',
                'No se pudo completar la tarea. Inténtalo de nuevo.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _edit(TaskEntity task) async {
    final generation = ref.read(authSessionBoundaryProvider).generation;
    final namespace = ref.read(accountStorageScopeProvider).v2Namespace;
    final draft = await showTaskEditDialog(
      context: context,
      editable: task,
      goals: ref.read(goalsProvider),
    );
    if (draft == null || !_sameAccount(generation, namespace)) return;
    try {
      await ref
          .read(taskActionsProvider)
          .updateTaskDetails(
            id: task.id,
            title: draft.title,
            description: draft.description,
            clearDescription: draft.description == null,
            priority: draft.priority,
            estimatedDuration: draft.estimatedDuration,
            clearEstimatedDuration: draft.estimatedDuration == null,
            scheduledFor: draft.scheduledFor,
            clearScheduledFor: draft.scheduledFor == null,
            dueDate: draft.dueDate,
            clearDueDate: draft.dueDate == null,
            goalId: draft.goalId,
            clearGoalId: draft.goalId == null,
          );
    } catch (_) {
      if (mounted && _sameAccount(generation, namespace)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Could not save your changes. Please try again.',
                'No se pudieron guardar los cambios. Inténtalo de nuevo.',
              ),
            ),
          ),
        );
      }
    }
  }
}
