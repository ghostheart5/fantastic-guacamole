import 'package:fantastic_guacamole/data/models/notification.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DebugPanel extends ConsumerWidget {
  const DebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final si = ref.watch(siStateProvider);
    final learning = ref.watch(learningProvider);
    final aiStatus = ref.watch(aiExecutionStatusProvider);

    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        width: 240,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),

        child: DefaultTextStyle(
          style: const TextStyle(fontSize: 11, color: Colors.white),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Title
                const Text("SI CONTROL", style: TextStyle(fontWeight: FontWeight.bold)),

                const SizedBox(height: 6),

                /// State display
                Text("Energy: ${si.energy.toStringAsFixed(2)}"),
                Text("Fatigue: ${si.fatigue.toStringAsFixed(2)}"),
                Text("Completed: ${learning.completed}"),
                Text("Skipped: ${learning.skipped}"),

                const SizedBox(height: 6),

                Text("EffortW: ${learning.effortWeight.toStringAsFixed(2)}"),
                Text("PriorityW: ${learning.priorityWeight.toStringAsFixed(2)}"),
                Text("AI: ${aiStatus.phase}"),
                if (aiStatus.requestId != null) Text("AI Req: ${aiStatus.requestId}"),
                if (aiStatus.durationMs != null) Text("AI Ms: ${aiStatus.durationMs}"),
                if (aiStatus.error != null)
                  Text("AI Err: ${aiStatus.error}", maxLines: 2, overflow: TextOverflow.ellipsis),

                const Divider(),

                /// Force energy
                Wrap(
                  spacing: 4,
                  children: [
                    _btn("Energy +", () {
                      ref.read(siStateProvider.notifier).adjustEnergy(0.1);
                    }),

                    _btn("Energy -", () {
                      ref.read(siStateProvider.notifier).adjustEnergy(-0.1);
                    }),
                  ],
                ),

                /// Force fatigue
                Wrap(
                  spacing: 4,
                  children: [
                    _btn("Fatigue +", () {
                      ref.read(siStateProvider.notifier).adjustFatigue(0.1);
                    }),

                    _btn("Fatigue -", () {
                      ref.read(siStateProvider.notifier).adjustFatigue(-0.1);
                    }),
                  ],
                ),

                const Divider(),

                /// Simulate behavior
                Wrap(
                  spacing: 4,
                  children: [
                    _btn("Complete Task", () async {
                      await ref
                          .read(learningProvider.notifier)
                          .update(success: true, difficulty: 3);
                      ref.read(siStateProvider.notifier).sessionComplete();
                      ref
                          .read(notificationProvider.notifier)
                          .push(
                            ChronoNotification(
                              id: 'debug-complete-${DateTime.now().microsecondsSinceEpoch}',
                              title: 'Debug Complete',
                              message: 'Simulated completion applied.',
                              type: ChronoNotificationType.completionFeedback,
                              priority: ChronoNotificationPriority.low,
                              timestamp: DateTime.now(),
                            ),
                          );
                    }),

                    _btn("Skip Task", () async {
                      await ref
                          .read(learningProvider.notifier)
                          .update(success: false, difficulty: 3);
                      ref.read(siStateProvider.notifier).taskSkipped();
                      ref
                          .read(notificationProvider.notifier)
                          .push(
                            ChronoNotification(
                              id: 'debug-skip-${DateTime.now().microsecondsSinceEpoch}',
                              title: 'Debug Skip',
                              message: 'Simulated skip applied.',
                              type: ChronoNotificationType.warning,
                              priority: ChronoNotificationPriority.low,
                              timestamp: DateTime.now(),
                            ),
                          );
                    }),
                  ],
                ),

                const Divider(),

                /// Force AI recompute
                _btn("Recompute AI", () {
                  ref.invalidate(aiResponseProvider);
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _btn(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
      ),
      child: Text(label, style: const TextStyle(fontSize: 10)),
    );
  }
}
