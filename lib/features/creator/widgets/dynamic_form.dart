import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/widgets/smart_pressable.dart';
import 'package:fantastic_guacamole/features/creator/widgets/type_selector.dart';
import 'package:flutter/material.dart';

class DynamicFormData {
  const DynamicFormData({
    required this.title,
    this.description,
    required this.type,
    required this.priority,
    this.scheduledFor,
  });

  final String title;
  final String? description;
  final String type;
  final int priority; // 1–5
  final DateTime? scheduledFor;
}

class DynamicForm extends StatefulWidget {
  const DynamicForm({super.key, required this.onSubmit});

  final ValueChanged<DynamicFormData> onSubmit;

  @override
  State<DynamicForm> createState() => _DynamicFormState();
}

class _DynamicFormState extends State<DynamicForm> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedType = 'Task';
  int _priority = 3;
  DateTime? _scheduledFor;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    widget.onSubmit(
      DynamicFormData(
        title: title,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        type: _selectedType,
        priority: _priority,
        scheduledFor: _scheduledFor,
      ),
    );
    _titleController.clear();
    _descController.clear();
    setState(() {
      _selectedType = 'Task';
      _priority = 3;
      _scheduledFor = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.memoryAmber.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.memoryAmber.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('TASK DETAILS', AppColors.memoryAmber),
          const SizedBox(height: 14),
          _buildTextField(_titleController, 'Title *', maxLines: 1),
          const SizedBox(height: 10),
          _buildTextField(
            _descController,
            'Description (optional)',
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          TypeSelector(
            selected: _selectedType,
            onSelect: (t) => setState(() => _selectedType = t),
          ),
          const SizedBox(height: 20),
          _PriorityPicker(
            value: _priority,
            onChanged: (v) => setState(() => _priority = v),
          ),
          const SizedBox(height: 20),
          _ScheduleDatePicker(
            selected: _scheduledFor,
            onPick: (date) => setState(() => _scheduledFor = date),
          ),
          const SizedBox(height: 20),
          SmartPressable(
            onTap: _submit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.memoryAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.memoryAmber.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.memoryAmber.withValues(alpha: 0.2),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Text(
                'FORGE TASK',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.memoryAmber,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: AppColors.neonCyan.withValues(alpha: 0.15),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: AppColors.neonCyan.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: AppColors.neonCyan.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 2,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2.5,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PriorityPicker extends StatelessWidget {
  const _PriorityPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 2,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.recallRed,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'PRIORITY',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.5,
                color: AppColors.recallRed,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '$value / 5',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.recallRed.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (i) {
            final level = i + 1;
            final isActive = level <= value;
            return Expanded(
              child: SmartPressable(
                onTap: () => onChanged(level),
                child: Container(
                  margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.recallRed.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppColors.recallRed.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ScheduleDatePicker extends StatelessWidget {
  const _ScheduleDatePicker({required this.selected, required this.onPick});

  final DateTime? selected;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    return SmartPressable(
      onTap: () {
        showDatePicker(
          context: context,
          initialDate: selected ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) =>
              Theme(data: ThemeData.dark(), child: child!),
        ).then(onPick);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.neonViolet.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: AppColors.neonViolet.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 10),
            Text(
              selected == null
                  ? 'Schedule for...'
                  : '${selected!.day}/${selected!.month}/${selected!.year}',
              style: TextStyle(
                fontSize: 13,
                color: selected == null ? Colors.white24 : Colors.white70,
              ),
            ),
            const Spacer(),
            if (selected != null)
              SmartPressable(
                onTap: () => onPick(null),
                child: const Icon(Icons.close, size: 14, color: Colors.white38),
              ),
          ],
        ),
      ),
    );
  }
}
