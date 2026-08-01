import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/domain/entities/completion_event_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final completionEventsProvider = Provider<List<CompletionEventEntity>>((
  Ref ref,
) {
  return ref.read(completionEventRepositoryProvider).getEvents();
});

final completionEventActionsProvider = Provider<CompletionEventActions>((
  Ref ref,
) {
  return CompletionEventActions(ref);
});

class CompletionEventActions {
  CompletionEventActions(this._ref);

  final Ref _ref;

  Future<void> clearAll() async {
    await _ref
        .read(completionEventRepositoryProvider)
        .saveEvents(const <CompletionEventEntity>[]);
    _ref.invalidate(completionEventsProvider);
  }

  Future<void> removeById(String id) async {
    await _ref.read(completionEventRepositoryProvider).removeEvent(id);
    _ref.invalidate(completionEventsProvider);
  }
}
