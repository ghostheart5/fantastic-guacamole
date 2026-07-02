import 'package:flutter/material.dart';

class TaskItem extends StatelessWidget {
  const TaskItem({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(title), subtitle: Text(subtitle));
  }
}
