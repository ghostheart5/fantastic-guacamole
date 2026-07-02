import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class FirstFocusScreen extends StatefulWidget {
  const FirstFocusScreen({super.key, required this.onStartFocus});

  final VoidCallback onStartFocus;

  @override
  State<FirstFocusScreen> createState() => _FirstFocusScreenState();
}

class _FirstFocusScreenState extends State<FirstFocusScreen> {
  int _selectedMinutes = 25;
  static const _durations = [15, 25, 45, 60];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050D1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR FIRST\nFOCUS SESSION',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set a duration and enter deep work mode.',
                style: TextStyle(fontSize: 13, color: Colors.white54),
              ),
              const SizedBox(height: 32),
              // Timer display
              Center(
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.neonCyan.withValues(alpha: 0.05),
                    border: Border.all(
                      color: AppColors.neonCyan.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonCyan.withValues(alpha: 0.12),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_selectedMinutes',
                          style: const TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w800,
                            color: AppColors.neonCyan,
                            height: 1,
                          ),
                        ),
                        const Text(
                          'MIN',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 3,
                            color: AppColors.neonCyan,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _durations.map((mins) {
                  final isSelected = _selectedMinutes == mins;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMinutes = mins),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.neonCyan.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.neonCyan.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          '${mins}m',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.neonCyan
                                : Colors.white38,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Tip(
                      icon: Icons.phone_android_outlined,
                      text: 'Put your phone face-down',
                    ),
                    SizedBox(height: 10),
                    _Tip(
                      icon: Icons.notifications_off_outlined,
                      text: 'Close unnecessary tabs',
                    ),
                    SizedBox(height: 10),
                    _Tip(
                      icon: Icons.task_alt_outlined,
                      text: 'Have one clear task in mind',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onStartFocus,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.neonCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.neonCyan.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonCyan.withValues(alpha: 0.25),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: const Text(
                    'START FOCUS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w800,
                      color: AppColors.neonCyan,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white38),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 13, color: Colors.white54)),
      ],
    );
  }
}
