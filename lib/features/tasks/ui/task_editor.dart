import 'package:flutter/material.dart';

class TaskEditor extends StatelessWidget {
  const TaskEditor({super.key, required this.controller, required this.onSave});

  final TextEditingController controller;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Task title'),
        ),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: onSave, child: const Text('Save')),
      ],
    );
  }
}
