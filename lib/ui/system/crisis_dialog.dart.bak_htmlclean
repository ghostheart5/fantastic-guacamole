import 'package:flutter/material.dart';

Future<void> showCrisisDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        "You're not alone",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'If you are in immediate danger, contact your local emergency number.',
            style: TextStyle(color: Color(0xFFB0B0C8), fontSize: 14),
          ),
          SizedBox(height: 16),
          Text(
            'In the United States, call or text 988 for the Suicide & Crisis Lifeline.',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
