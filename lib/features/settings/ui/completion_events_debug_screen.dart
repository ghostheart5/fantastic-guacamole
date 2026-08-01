import 'package:fantastic_guacamole/domain/entities/completion_event_entity.dart';
import 'package:fantastic_guacamole/state/providers/completion_events_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CompletionEventsDebugScreen extends ConsumerWidget {
  const CompletionEventsDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<CompletionEventEntity> events = ref.watch(
      completionEventsProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Completion Events Inspector'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(completionEventsProvider),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Clear all',
            onPressed: events.isEmpty
                ? null
                : () async {
                    await ref.read(completionEventActionsProvider).clearAll();
                  },
            icon: const Icon(Icons.delete_sweep),
          ),
        ],
      ),
      body: events.isEmpty
          ? const Center(child: Text('No completion events recorded yet.'))
          : ListView.separated(
              itemCount: events.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final CompletionEventEntity event = events[index];
                final String title =
                    event.taskId == null || event.taskId!.trim().isEmpty
                    ? event.eventType.name
                    : '${event.eventType.name} · ${event.taskId}';
                final String subtitle =
                    '${event.eventAt.toLocal().toIso8601String()}\nsource: ${event.source ?? 'unknown'}';

                return ListTile(
                  dense: true,
                  title: Text(title),
                  subtitle: Text(subtitle),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Delete event',
                    onPressed: () async {
                      await ref
                          .read(completionEventActionsProvider)
                          .removeById(event.id);
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                );
              },
            ),
    );
  }
}
