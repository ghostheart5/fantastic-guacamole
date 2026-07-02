import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key, required this.onComplete});

  final void Function(double energy, double focus, int availableMinutes)
  onComplete;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  double _energy = 0.7;
  double _focus = 0.7;
  int _availableMinutes = 60;

  static const _timeOptions = [15, 30, 45, 60, 90, 120];

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
                'SYSTEM\nCALIBRATION',
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
                'Help ChronoSpark understand your current state.',
                style: TextStyle(fontSize: 13, color: Colors.white54),
              ),
              const SizedBox(height: 32),
              _panel(
                label: 'ENERGY LEVEL',
                color: AppColors.neonCyan,
                child: _slider(
                  _energy,
                  AppColors.neonCyan,
                  (v) => setState(() => _energy = v),
                ),
              ),
              const SizedBox(height: 16),
              _panel(
                label: 'FOCUS CAPACITY',
                color: AppColors.neonViolet,
                child: _slider(
                  _focus,
                  AppColors.neonViolet,
                  (v) => setState(() => _focus = v),
                ),
              ),
              const SizedBox(height: 16),
              _panel(
                label: 'AVAILABLE TIME',
                color: AppColors.memoryAmber,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _timeOptions.map((mins) {
                    final isSelected = _availableMinutes == mins;
                    return GestureDetector(
                      onTap: () => setState(() => _availableMinutes = mins),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.memoryAmber.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.memoryAmber.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          '${mins}m',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.memoryAmber
                                : Colors.white38,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    widget.onComplete(_energy, _focus, _availableMinutes),
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
                        color: AppColors.neonCyan.withValues(alpha: 0.2),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Text(
                    'CALIBRATE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 2.5,
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

  Widget _panel({
    required String label,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                label,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.5,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _slider(double value, Color color, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: color,
              inactiveTrackColor: Colors.white12,
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(value: value, onChanged: onChanged),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 36,
          child: Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
