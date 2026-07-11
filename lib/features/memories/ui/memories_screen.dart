import 'package:fantastic_guacamole/core/utils/date_time_formats.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MemoriesScreen extends ConsumerWidget {
  const MemoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(memoriesProvider);
    final starred = all.where((m) => m.starred).toList();
    final unstarred = all.where((m) => !m.starred).toList();
    final sorted = [...starred, ...unstarred];

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/progression_bg.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Row(
                  children: [
                    SmartPressable(
                      onTap: () =>
                          ref.read(appFlowProvider.notifier).toSmartCoach(),
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
                        color: AppColors.neonViolet,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonViolet.withValues(alpha: 0.8),
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
                            colors: [AppColors.neonViolet, AppColors.neonCyan],
                          ).createShader(bounds),
                          child: const Text(
                            'MEMORIES',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Text(
                          'WHAT YOU\'VE LIVED',
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
              ),
              const SizedBox(height: 20),
              Expanded(
                child: sorted.isEmpty
                    ? const Center(
                        child: Text(
                          'Complete a reflection to\ncapture your first memory.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                        itemCount: sorted.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _MemoryCard(
                          memory: sorted[i],
                          onToggleStar: () => ref
                              .read(memoriesProvider.notifier)
                              .toggleStar(sorted[i].id),
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

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.memory, required this.onToggleStar});

  final MemoryEntity memory;
  final VoidCallback onToggleStar;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateTimeFormats.dateShort(memory.date);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: memory.starred
              ? AppColors.memoryAmber.withValues(alpha: 0.4)
              : AppColors.neonViolet.withValues(alpha: 0.15),
        ),
        boxShadow: memory.starred
            ? [
                BoxShadow(
                  color: AppColors.memoryAmber.withValues(alpha: 0.08),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.neonViolet.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      color: AppColors.neonViolet,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  memory.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onToggleStar,
            child: Icon(
              memory.starred ? Icons.star_rounded : Icons.star_border_rounded,
              color: memory.starred ? AppColors.memoryAmber : Colors.white24,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}
