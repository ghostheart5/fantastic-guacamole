import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';

class QuickInputBar extends StatefulWidget {
  const QuickInputBar({super.key, required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<QuickInputBar> createState() => _QuickInputBarState();
}

class _QuickInputBarState extends State<QuickInputBar> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonCyan.withValues(alpha: 0.06),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.neonCyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.neonCyan.withValues(alpha: 0.2),
              ),
            ),
            child: const Icon(Icons.add, color: AppColors.neonCyan, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Quick add...',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedOpacity(
            opacity: _hasText ? 1.0 : 0.3,
            duration: const Duration(milliseconds: 150),
            child: SmartPressable(
              onTap: _hasText ? _submit : () {},
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _hasText
                      ? AppColors.neonCyan.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _hasText
                        ? AppColors.neonCyan.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Icon(
                  Icons.send_rounded,
                  size: 15,
                  color: _hasText ? AppColors.neonCyan : Colors.white24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
