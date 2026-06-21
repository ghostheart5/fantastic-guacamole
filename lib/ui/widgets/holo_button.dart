import 'package:flutter/material.dart';

class HoloButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const HoloButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.cyanAccent),
          boxShadow: [BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.6), blurRadius: 10)],
        ),
        child: Center(
          child: Text(label, style: const TextStyle(color: Colors.cyanAccent)),
        ),
      ),
    );
  }
}
