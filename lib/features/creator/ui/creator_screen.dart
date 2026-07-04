import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/widgets/smart_pressable.dart';
import 'package:fantastic_guacamole/features/creator/creator_provider.dart';
import 'package:fantastic_guacamole/features/creator/widgets/dynamic_form.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreatorScreen extends ConsumerWidget {
  const CreatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/creator_bg.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SmartPressable(
                      onTap: () => ref.read(appFlowProvider.notifier).toCoach(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.neonCyan.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.neonCyan,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 3,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.memoryAmber,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.memoryAmber.withValues(alpha: 0.8),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.memoryAmber, AppColors.neonCyan],
                          ).createShader(bounds),
                          child: const Text(
                            'CREATOR',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Text(
                          'TASK FORGE',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _TypeGuideCard(),
                const SizedBox(height: 16),
                DynamicForm(
                  onSubmit: (data) async {
                    await ref.read(creatorActionsProvider).createTask(data);
                    if (context.mounted) {
                      ref.read(appFlowProvider.notifier).toCoach();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeGuideCard extends StatelessWidget {
  const _TypeGuideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.memoryAmber.withValues(alpha: 0.15),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TYPES',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 2.5,
              color: AppColors.memoryAmber,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10),
          _TypeRow(
            icon: Icons.check_circle_outline,
            label: 'Task',
            desc: 'something to complete',
          ),
          SizedBox(height: 6),
          _TypeRow(
            icon: Icons.repeat_rounded,
            label: 'Routine',
            desc: 'repeat daily',
          ),
          SizedBox(height: 6),
          _TypeRow(
            icon: Icons.timer_outlined,
            label: 'Focus',
            desc: 'timed session',
          ),
          SizedBox(height: 6),
          _TypeRow(
            icon: Icons.flag_outlined,
            label: 'Mission',
            desc: 'long-term goal',
          ),
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.icon, required this.label, required this.desc});
  final IconData icon;
  final String label;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.neonCyan, size: 13),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '— $desc',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
