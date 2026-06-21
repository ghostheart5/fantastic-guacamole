import 'package:flutter/material.dart';

class TaskInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final String hintText;
  final String buttonLabel;

  const TaskInput({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.hintText = 'Enter task',
    this.buttonLabel = 'Add',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: hintText),
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(onPressed: onSubmit, child: Text(buttonLabel)),
      ],
    );
  }
}
