import 'package:fantastic_guacamole/domain/entities/completion_event_entity.dart';

abstract class ICompletionEventRepository {
  List<CompletionEventEntity> getEvents();
  Future<void> addEvent(CompletionEventEntity event);
  Future<void> saveEvents(List<CompletionEventEntity> events);
  Future<void> removeEvent(String id);
}
