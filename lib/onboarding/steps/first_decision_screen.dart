import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class FirstDecisionScreen extends StatefulWidget {
  const FirstDecisionScreen({super.key, required this.onDecision});

  final ValueChanged<String> onDecision;

  @override
  State<FirstDecisionScreen> createState() => _FirstDecisionScreenState();
}

class _FirstDecisionScreenState extends State<FirstDecisionScreen> {
  String? _selected;

  static const _choices = [
    _DecisionChoice(
      id: 'do',
      label: 'Do It Now',
      description: 'Tackle this task immediately',
      icon: Icons.bolt_outlined,
      color: AppColors.neonCyan,
    ),
    _DecisionChoice(
      id: 'schedule',
      label: 'Schedule It',
      description: 'Block time for this later',
      icon: Icons.schedule_outlined,
      color: AppColors.neonViolet,
    ),
    _DecisionChoice(
      id: 'delegate',
      label: 'Delegate',
      description: 'Assign this to someone else',
      icon: Icons.person_add_outlined,
      color: AppColors.memoryAmber,
    ),
    _DecisionChoice(
      id: 'drop',
      label: 'Drop It',
      description: 'Remove it — it is not worth your time',
      icon: Icons.delete_outline,
      color: AppColors.recallRed,
    ),
  ];

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
                'YOUR FIRST\nDECISION',
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
                'Every task deserves a clear verdict.',
                style: TextStyle(fontSize: 13, color: Colors.white54),
              ),
              const SizedBox(height: 24),
              // Sample task card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.neonCyan,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonCyan.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Review project proposal',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Example task — what would you do with this?',
                            style: TextStyle(fontSize: 12, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.3,
                  physics: const NeverScrollableScrollPhysics(),
                  children: _choices.map((choice) {
                    final isSelected = _selected == choice.id;
                    return GestureDetector(
                      onTap: () => setState(() => _selected = choice.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? choice.color.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? choice.color.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.08),
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: choice.color.withValues(alpha: 0.15),
                                    blurRadius: 12,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              choice.icon,
                              color: isSelected ? choice.color : Colors.white38,
                              size: 22,
                            ),
                            const Spacer(),
                            Text(
                              choice.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? choice.color : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              choice.description,
                              style: const TextStyle(fontSize: 10, color: Colors.white38),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _selected == null
                    ? null
                    : () {
                        final String? selected = _selected;
                        if (selected != null) {
                          widget.onDecision(selected);
                        }
                      },
                child: AnimatedOpacity(
                  opacity: _selected == null ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.neonCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      'LOCK IN DECISION',
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DecisionChoice {
  const _DecisionChoice({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
}
