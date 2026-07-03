import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class IntentSelection extends StatefulWidget {
  const IntentSelection({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  State<IntentSelection> createState() => _IntentSelectionState();
}

class _IntentSelectionState extends State<IntentSelection> {
  String? _selected;

  static const _intents = [
    _IntentOption(
      id: 'deep_work',
      label: 'Deep Work',
      description: 'Long focused sessions on complex tasks',
      icon: Icons.psychology_outlined,
      color: AppColors.neonCyan,
    ),
    _IntentOption(
      id: 'light_tasks',
      label: 'Light Tasks',
      description: 'Quick wins and admin work',
      icon: Icons.check_circle_outline,
      color: AppColors.neonViolet,
    ),
    _IntentOption(
      id: 'planning',
      label: 'Planning',
      description: 'Organise and schedule your day',
      icon: Icons.calendar_month_outlined,
      color: AppColors.memoryAmber,
    ),
    _IntentOption(
      id: 'rest',
      label: 'Rest & Recovery',
      description: 'Low demand — restore energy',
      icon: Icons.self_improvement_outlined,
      color: AppColors.recallRed,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WHAT IS YOUR\nINTENT TODAY?',
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
            'ChronoSpark adapts to your current mode.',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.separated(
              itemCount: _intents.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final intent = _intents[i];
                final isSelected = _selected == intent.id;
                return GestureDetector(
                  onTap: () => setState(() => _selected = intent.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? intent.color.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? intent.color.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.08),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: intent.color.withValues(alpha: 0.15),
                                blurRadius: 16,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: intent.color.withValues(
                              alpha: isSelected ? 0.15 : 0.06,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: intent.color.withValues(
                                alpha: isSelected ? 0.5 : 0.2,
                              ),
                            ),
                          ),
                          child: Icon(
                            intent.icon,
                            color: intent.color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                intent.label,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? intent.color
                                      : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                intent.description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: intent.color,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _selected == null
                ? null
                : () {
                    final String? selected = _selected;
                    if (selected != null) {
                      widget.onSelected(selected);
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
                  'CONFIRM INTENT',
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
    );
  }
}

class _IntentOption {
  const _IntentOption({
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
