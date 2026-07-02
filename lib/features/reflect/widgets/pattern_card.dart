import 'package:flutter/material.dart';

class PatternCard extends StatelessWidget {
  const PatternCard({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title);
  }
}
