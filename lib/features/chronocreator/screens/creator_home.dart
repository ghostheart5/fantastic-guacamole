import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../data/services/workspace_store_service.dart';
import '../../../ui/widgets/chronospark_bottom_nav.dart';
import '../../../ui/layout/holo_background.dart';
import '../../../ui/widgets/panel_container.dart';

class CreatorHome extends StatefulWidget {
  const CreatorHome({super.key});

  @override
  State<CreatorHome> createState() => _CreatorHomeState();
}

class _CreatorHomeState extends State<CreatorHome> {
  final WorkspaceStoreService _store = WorkspaceStoreService();
  final TextEditingController _siController = TextEditingController();
  final List<String> _tasksEvents = <String>[];
  final List<String> _goals = <String>[];
  final List<String> _routines = <String>[];
  final List<String> _siOutputs = <String>[];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _siController.dispose();
    super.dispose();
  }

  void _createTaskEvent() {
    setState(() {
      _tasksEvents.insert(0, 'Task/Event ${_tasksEvents.length + 1} created');
    });
    _persistState();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('New task/event created')));
  }

  void _createGoal() {
    setState(() {
      _goals.insert(0, 'Goal ${_goals.length + 1} created');
    });
    _persistState();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New goal created')));
  }

  void _createRoutine() {
    setState(() {
      _routines.insert(0, 'Routine ${_routines.length + 1} created');
    });
    _persistState();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('New routine created')));
  }

  void _runSiCreate() {
    final String prompt = _siController.text.trim();
    if (prompt.isEmpty) {
      return;
    }

    final String lower = prompt.toLowerCase();
    String output;
    if (lower.contains('organize monday')) {
      output =
          'SI plan for Monday: 9:00 Focus Sprint, 11:00 Review ChronoLogs, 1:00 Deep Work Block, 4:00 Mission Wrap.';
    } else if (lower.contains('goal')) {
      output = 'SI created a new goal sequence with milestones and weekly checkpoints.';
    } else if (lower.contains('routine')) {
      output = 'SI generated a routine: Morning calibration, midday execution, evening reflection.';
    } else if (lower.contains('event') || lower.contains('task')) {
      output = 'SI created tasks/events and distributed them across the optimal energy windows.';
    } else {
      output =
          'SI created an optimized plan from your request and aligned it with focus windows and mission priorities.';
    }

    setState(() {
      _siOutputs.insert(0, output);
      _siController.clear();
    });
    _persistState();
  }

  Future<void> _loadState() async {
    final CreatorWorkspaceState state = await _store.loadCreatorState();
    if (!mounted) {
      return;
    }

    setState(() {
      _tasksEvents
        ..clear()
        ..addAll(state.tasksEvents);
      _goals
        ..clear()
        ..addAll(state.goals);
      _routines
        ..clear()
        ..addAll(state.routines);
      _siOutputs
        ..clear()
        ..addAll(state.siOutputs);
    });
  }

  Future<void> _persistState() async {
    await _store.saveCreatorState(
      CreatorWorkspaceState(
        tasksEvents: List<String>.from(_tasksEvents),
        goals: List<String>.from(_goals),
        routines: List<String>.from(_routines),
        siOutputs: List<String>.from(_siOutputs),
      ),
    );
  }

  Widget _createAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 172,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.sm),
          decoration: BoxDecoration(
            color: AppColors.panelGlassAlt,
            borderRadius: BorderRadius.circular(AppSizes.radius),
            border: Border.all(color: AppColors.panelBorder),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, color: AppColors.neonCyanAlt),
              const SizedBox(width: AppSizes.sm),
              Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statPill(BuildContext context, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSizes.sm),
        decoration: BoxDecoration(
          color: AppColors.panelGlassAlt,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          border: Border.all(color: AppColors.panelBorder),
        ),
        child: Column(
          children: <Widget>[
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _siOutputCard(BuildContext context, String output) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: AppColors.panelGlassAlt,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.55)),
      ),
      child: Text(output),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HoloBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.md),
            children: <Widget>[
              PanelContainer(
                title: 'CHRONOCREATOR',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Creation Engine - SI-native planning and generation deck.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Row(
                      children: <Widget>[
                        _statPill(context, 'Tasks/Events', _tasksEvents.length.toString()),
                        const SizedBox(width: AppSizes.sm),
                        _statPill(context, 'Goals', _goals.length.toString()),
                        const SizedBox(width: AppSizes.sm),
                        _statPill(context, 'Routines', _routines.length.toString()),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),
              PanelContainer(
                title: 'CREATE',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Action Rail', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSizes.xs),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: <Widget>[
                          _createAction(
                            context,
                            icon: Icons.task_alt,
                            label: 'New Tasks/Events',
                            onTap: _createTaskEvent,
                          ),
                          const SizedBox(width: AppSizes.sm),
                          _createAction(
                            context,
                            icon: Icons.flag,
                            label: 'New Goals',
                            onTap: _createGoal,
                          ),
                          const SizedBox(width: AppSizes.sm),
                          _createAction(
                            context,
                            icon: Icons.repeat,
                            label: 'New Routine',
                            onTap: _createRoutine,
                          ),
                          const SizedBox(width: AppSizes.sm),
                          _createAction(
                            context,
                            icon: Icons.psychology_alt,
                            label: 'SI Creation',
                            onTap: () {
                              if (_siController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Enter an SI request first.')),
                                );
                                return;
                              }
                              _runSiCreate();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),
              PanelContainer(
                title: 'SI CREATION ASSISTANT',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextField(
                      controller: _siController,
                      decoration: const InputDecoration(
                        hintText: 'Ask SI to create (example: si organize monday)',
                      ),
                      onSubmitted: (_) => _runSiCreate(),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    FilledButton.icon(
                      onPressed: _runSiCreate,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Run SI Orchestration'),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    if (_siOutputs.isEmpty)
                      const Text('SI output appears here after your request.')
                    else
                      ..._siOutputs.take(4).map((String output) => _siOutputCard(context, output)),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),
              PanelContainer(
                title: 'RECENT CREATION STREAM',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Tasks/Events: ${_tasksEvents.take(3).join(' | ')}'),
                    const SizedBox(height: AppSizes.xs),
                    Text('Goals: ${_goals.take(3).join(' | ')}'),
                    const SizedBox(height: AppSizes.xs),
                    Text('Routines: ${_routines.take(3).join(' | ')}'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ChronoSparkBottomNav(selectedIndex: 1),
    );
  }
}
