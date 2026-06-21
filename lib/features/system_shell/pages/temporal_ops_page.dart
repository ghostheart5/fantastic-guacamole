import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_state.dart';
import '../../../ui/system/glass_panel.dart';

enum TemporalMode { day, week, month }

class TemporalOpsPage extends StatefulWidget {
  const TemporalOpsPage({super.key});

  @override
  State<TemporalOpsPage> createState() => _TemporalOpsPageState();
}

class _TemporalOpsPageState extends State<TemporalOpsPage> with SingleTickerProviderStateMixin {
  TemporalMode _mode = TemporalMode.day;
  int _selectedDay = DateTime.now().weekday - 1;
  bool _focusMode = false;
  late final AnimationController _ringPulse;
  final TextEditingController _taskController = TextEditingController();

  final List<_TaskItem> _tasks = <_TaskItem>[
    const _TaskItem(id: '1', title: '09:00 Focus Start'),
    const _TaskItem(id: '2', title: '12:00 Recovery Block'),
    const _TaskItem(id: '3', title: '15:00 Deadline Sprint'),
  ];

  final Set<String> _enteringTaskIds = <String>{};
  final Set<String> _completingTaskIds = <String>{};

  static const List<String> _days = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _ringPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
      lowerBound: 0.965,
      upperBound: 1.025,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ringPulse.dispose();
    _taskController.dispose();
    super.dispose();
  }

  void _selectDay(int index) {
    setState(() {
      _selectedDay = index;
      _focusMode = true;
    });
    Future<void>.delayed(const Duration(milliseconds: 850), () {
      if (!mounted) {
        return;
      }
      setState(() => _focusMode = false);
    });
  }

  void _setMode(TemporalMode mode) {
    setState(() {
      _mode = mode;
      _focusMode = true;
    });
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) {
        return;
      }
      setState(() => _focusMode = false);
    });
  }

  void _addTask() {
    final String value = _taskController.text.trim();
    if (value.isEmpty) {
      return;
    }
    final String id = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _tasks.insert(0, _TaskItem(id: id, title: value));
      _enteringTaskIds.add(id);
      _taskController.clear();
      _focusMode = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AppState>().addTask(title: value, priority: 7);
      setState(() => _enteringTaskIds.remove(id));
    });
  }

  void _toggleTask(_TaskItem item) {
    if (item.done) {
      return;
    }

    setState(() {
      _completingTaskIds.add(item.id);
      _focusMode = true;
    });

    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) {
        return;
      }
      setState(() {
        final int index = _tasks.indexWhere((_TaskItem t) => t.id == item.id);
        if (index != -1) {
          _tasks[index] = _tasks[index].copyWith(done: true);
        }
        context.read<AppState>().completeTask(item.title);
        _completingTaskIds.remove(item.id);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 260),
              opacity: _focusMode ? 0.28 : 0.12,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x99040307), Color(0xB306040B)],
                  ),
                ),
              ),
            ),
          ),
        ),
        ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _ModeSelector(mode: _mode, onChanged: _setMode),
            const SizedBox(height: 12),
            _buildDaySelector(),
            const SizedBox(height: 12),
            AnimatedScale(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              scale: _focusMode ? 0.994 : 1,
              child: GlassPanel(isActive: true, child: _buildFocusPanel()),
            ),
            const SizedBox(height: 12),
            GlassPanel(
              isActive: _focusMode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Task Stream',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _taskController,
                          decoration: const InputDecoration(labelText: 'Add task for selected day'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _GlowActionButton(label: 'Add', onTap: _addTask),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._tasks.map((_TaskItem task) {
                    return _AnimatedTaskTile(
                      task: task,
                      entering: _enteringTaskIds.contains(task.id),
                      completing: _completingTaskIds.contains(task.id),
                      onChanged: () => _toggleTask(task),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDaySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List<Widget>.generate(_days.length, (int index) {
        return _DayChip(
          label: _days[index],
          isSelected: _selectedDay == index,
          onTap: () => _selectDay(index),
        );
      }),
    );
  }

  Widget _buildFocusPanel() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: SizedBox(
        key: ValueKey<String>('${_mode.name}:$_selectedDay'),
        height: 240,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Center(
                child: AnimatedBuilder(
                  animation: _ringPulse,
                  builder: (BuildContext context, Widget? child) {
                    return Transform.scale(scale: _ringPulse.value, child: child);
                  },
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 260),
                    opacity: _focusMode ? 0.16 : 0.1,
                    child: Image.asset(
                      'assets/grid/temporal_grid.png',
                      fit: BoxFit.contain,
                      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  alignment: Alignment(-0.9 + (_selectedDay / 6) * 1.8, 0.0),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 240),
                    opacity: _focusMode ? 0.32 : 0.18,
                    child: Image.asset(
                      'assets/glows/glow_primary.png',
                      width: 220,
                      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.all(8), child: _modeBody(_mode)),
          ],
        ),
      ),
    );
  }

  Widget _modeBody(TemporalMode mode) {
    if (mode == TemporalMode.day) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${_days[_selectedDay]} Timeline',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Primary focus: ${_tasks.first.title}',
            style: const TextStyle(color: Color(0xFFD8D0E6)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Context lock: 2 interruption shields active',
            style: TextStyle(color: Color(0xFFD8D0E6)),
          ),
          const SizedBox(height: 6),
          const Text('Energy trend: Stable', style: TextStyle(color: Color(0xFFD8D0E6))),
        ],
      );
    }

    if (mode == TemporalMode.week) {
      return Row(
        children: List<Widget>.generate(_days.length, (int index) {
          final bool active = _selectedDay == index;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              margin: EdgeInsets.only(right: index == _days.length - 1 ? 0 : 4),
              decoration: BoxDecoration(
                color: active ? const Color(0x2EC2A7FF) : const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active ? const Color(0x88C2A7FF) : const Color(0x33FFFFFF),
                ),
              ),
              child: Center(
                child: Text(
                  _days[index],
                  style: TextStyle(
                    color: active ? const Color(0xFFF0EAFF) : const Color(0xFFA89FB8),
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      );
    }

    return SizedBox(
      height: 220,
      child: Stack(
        children: const <Widget>[
          Positioned(left: 20, top: 20, child: _Node()),
          Positioned(left: 140, top: 70, child: _Node()),
          Positioned(left: 260, top: 30, child: _Node()),
          Positioned(left: 80, top: 150, child: _Node()),
          Positioned(left: 220, top: 170, child: _Node()),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final TemporalMode mode;
  final ValueChanged<TemporalMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: TemporalMode.values.map((TemporalMode value) {
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _GlowActionButton(
            label: switch (value) {
              TemporalMode.day => 'ChronoFlow',
              TemporalMode.week => 'ArcView',
              TemporalMode.month => 'Constellation',
            },
            isActive: mode == value,
            onTap: () => onChanged(value),
          ),
        );
      }).toList(),
    );
  }
}

class _DayChip extends StatefulWidget {
  const _DayChip({required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_DayChip> createState() => _DayChipState();
}

class _DayChipState extends State<_DayChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: _pressed ? 0.98 : 1,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: widget.isSelected ? (_pressed ? 0.4 : 0.25) : 0,
                  child: Image.asset(
                    'assets/glows/glow_secondary.png',
                    fit: BoxFit.cover,
                    errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isSelected ? const Color(0x2EC2A7FF) : const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isSelected ? const Color(0x88C2A7FF) : const Color(0x33FFFFFF),
                ),
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected ? const Color(0xFFF2EDFF) : const Color(0xFFA89FB8),
                  fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowActionButton extends StatefulWidget {
  const _GlowActionButton({required this.label, required this.onTap, this.isActive = false});

  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  State<_GlowActionButton> createState() => _GlowActionButtonState();
}

class _GlowActionButtonState extends State<_GlowActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: _pressed ? 0.98 : 1,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: (widget.isActive || _pressed) ? (_pressed ? 0.35 : 0.24) : 0,
                  child: Image.asset(
                    'assets/glows/glow_primary.png',
                    fit: BoxFit.cover,
                    errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isActive ? const Color(0x2DC2A7FF) : const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isActive ? const Color(0x88C2A7FF) : const Color(0x33FFFFFF),
                ),
              ),
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: Color(0xFFECE8F9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedTaskTile extends StatelessWidget {
  const _AnimatedTaskTile({
    required this.task,
    required this.entering,
    required this.completing,
    required this.onChanged,
  });

  final _TaskItem task;
  final bool entering;
  final bool completing;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      offset: entering ? const Offset(0.08, 0) : Offset.zero,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 240),
        opacity: completing ? 0.35 : 1,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 220),
          scale: completing ? 0.975 : 1,
          child: Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: task.done,
              onChanged: (_) => onChanged(),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(
                task.title,
                style: TextStyle(
                  color: const Color(0xFFD8D0E6),
                  decoration: task.done ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskItem {
  const _TaskItem({required this.id, required this.title, this.done = false});

  final String id;
  final String title;
  final bool done;

  _TaskItem copyWith({String? id, String? title, bool? done}) {
    return _TaskItem(id: id ?? this.id, title: title ?? this.title, done: done ?? this.done);
  }
}

class _Node extends StatelessWidget {
  const _Node();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: Color(0xFFC2A7FF),
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[BoxShadow(color: Color(0x55C2A7FF), blurRadius: 12)],
      ),
    );
  }
}
