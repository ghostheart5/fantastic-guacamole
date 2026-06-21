import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../data/services/workspace_store_service.dart';
import '../../../ui/layout/holo_background.dart';
import '../../../ui/widgets/chronospark_bottom_nav.dart';
import '../../../ui/widgets/panel_container.dart';

class TemporalOpsHome extends StatefulWidget {
  const TemporalOpsHome({super.key});

  @override
  State<TemporalOpsHome> createState() => _TemporalOpsHomeState();
}

class _TemporalOpsHomeState extends State<TemporalOpsHome> {
  final WorkspaceStoreService _store = WorkspaceStoreService();

  static const List<String> _days = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _selectedDay = 'Mon';
  List<_PlannerItem> _timelineItems = const <_PlannerItem>[];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final TemporalPlannerState state = await _store.loadTemporalState();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedDay = state.selectedDay;
      _timelineItems = state.timelineItems
          .map(
            (PlannerTimelineItem item) => _PlannerItem(
              item.time,
              item.title,
              item.kind,
              _PlannerItem.colorFromHex(item.colorHex),
            ),
          )
          .toList();
    });
  }

  Future<void> _persistState() async {
    await _store.saveTemporalState(
      TemporalPlannerState(
        selectedDay: _selectedDay,
        timelineItems: _timelineItems
            .map(
              (_PlannerItem item) => PlannerTimelineItem(
                time: item.time,
                title: item.title,
                kind: item.kind,
                colorHex: item.colorHex,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _dayChip(String day) {
    final bool selected = _selectedDay == day;
    return Padding(
      padding: const EdgeInsets.only(right: AppSizes.sm),
      child: ChoiceChip(
        label: Text(day),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedDay = day);
          _persistState();
        },
      ),
    );
  }

  Widget _timelineRow(BuildContext context, _PlannerItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 56,
            child: Text(
              item.time,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
          Column(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
              ),
              Container(width: 2, height: 42, color: AppColors.panelBorder),
            ],
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: AppColors.panelGlassAlt,
                borderRadius: BorderRadius.circular(AppSizes.radius),
                border: Border.all(color: item.color.withValues(alpha: 0.6), width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    item.kind,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard(BuildContext context, String title, String line1, String line2) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSizes.sm),
        decoration: BoxDecoration(
          color: AppColors.panelGlassAlt,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          border: Border.all(color: AppColors.panelBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSizes.xs),
            Text(line1, style: Theme.of(context).textTheme.bodySmall),
            Text(
              line2,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<_PlannerItem> timeline = _timelineItems.isEmpty
        ? _PlannerItem.defaults
        : _timelineItems;

    return Scaffold(
      body: HoloBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.md),
            children: <Widget>[
              PanelContainer(
                title: 'TEMPORAL OPS',
                child: Text(
                  'Planner view for $_selectedDay: timeline, schedule, intelligence, and output.',
                ),
              ),
              const SizedBox(height: AppSizes.md),
              PanelContainer(
                title: 'Planner Strip',
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: _days.map(_dayChip).toList()),
                ),
              ),
              const SizedBox(height: AppSizes.md),
              PanelContainer(
                title: 'Timeline Planner',
                child: Column(
                  children: timeline.map((item) => _timelineRow(context, item)).toList(),
                ),
              ),
              const SizedBox(height: AppSizes.md),
              PanelContainer(
                title: 'Schedule Board',
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        _scheduleCard(context, 'Focus Blocks', '3 scheduled', '2h 45m deep work'),
                        const SizedBox(width: AppSizes.sm),
                        _scheduleCard(context, 'Events', '2 meetings', '1 conflict detected'),
                      ],
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Row(
                      children: <Widget>[
                        _scheduleCard(
                          context,
                          'Reviews',
                          '1 review cycle',
                          'ChronoLogs at 1:00 PM',
                        ),
                        const SizedBox(width: AppSizes.sm),
                        _scheduleCard(context, 'Buffer', '2 recovery slots', '3:30 PM and 5:30 PM'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),
              const PanelContainer(
                title: 'Time Intelligence',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Peak window: 9:00 AM - 11:00 AM'),
                    SizedBox(height: AppSizes.xs),
                    Text('Predicted bottleneck: 3:00 PM due to stacked context switches'),
                    SizedBox(height: AppSizes.xs),
                    Text('Recommendation: move admin tasks after 4:30 PM'),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),
              const PanelContainer(
                title: 'Output Plan',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('1. Lock mission-critical work before noon.'),
                    SizedBox(height: AppSizes.xs),
                    Text('2. Convert one event slot into execution buffer.'),
                    SizedBox(height: AppSizes.xs),
                    Text('3. Trigger SI recalibration after 2:30 PM check.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ChronoSparkBottomNav(selectedIndex: 3),
    );
  }
}

class _PlannerItem {
  const _PlannerItem(this.time, this.title, this.kind, this.color);

  final String time;
  final String title;
  final String kind;
  final Color color;

  String get colorHex => '0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  static Color colorFromHex(String value) {
    final String cleaned = value.startsWith('0x') ? value.substring(2) : value;
    final int parsed = int.tryParse(cleaned, radix: 16) ?? 0xFF00F0FF;
    return Color(parsed);
  }

  static const List<_PlannerItem> defaults = <_PlannerItem>[
    _PlannerItem('08:30', 'Morning Calibration', 'Focus Block', AppColors.neonCyan),
    _PlannerItem('10:00', 'Tactical Routine Update', 'High Priority', AppColors.recallRed),
    _PlannerItem('13:00', 'ChronoLogs Review', 'Review', AppColors.memoryAmber),
    _PlannerItem('15:00', 'Team Sync', 'Event', AppColors.neonViolet),
    _PlannerItem('16:30', 'Output Plan Lock', 'Execution', AppColors.neonGreen),
  ];
}
