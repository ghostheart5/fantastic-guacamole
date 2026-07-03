import 'package:flutter/material.dart';

const _crisisKeywords = [
  'suicide',
  'kill myself',
  'end my life',
  'self harm',
  'self-harm',
  'want to die',
  'hurt myself',
];

bool isCrisis(String input) {
  final lower = input.toLowerCase();
  return _crisisKeywords.any((k) => lower.contains(k));
}

Future<void> showCrisisDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
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
        children: [
          Text(
            'If you are in immediate danger, please contact your local emergency number.',
            style: TextStyle(color: Color(0xFFB0B0C8), fontSize: 14),
          ),
          SizedBox(height: 16),
          Text(
            'You can also reach:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          _CrisisLine(label: '988', detail: 'US Suicide & Crisis Lifeline'),
          SizedBox(height: 4),
          _CrisisLine(label: 'Local services', detail: 'crisis center near you'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text(
            'OK',
            style: TextStyle(color: Color(0xFF9B8AFB), fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _CrisisLine extends StatelessWidget {
  const _CrisisLine({required this.label, required this.detail});
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.phone, color: Color(0xFF9B8AFB), size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const Text(
          ' — ',
          style: TextStyle(color: Color(0xFF9B8AFB), fontSize: 13),
        ),
        Flexible(
          child: Text(
            detail,
            style: const TextStyle(color: Color(0xFFB0B0C8), fontSize: 13),
          ),
        ),
      ],
    );
  }
}
