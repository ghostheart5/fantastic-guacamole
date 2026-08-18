/// CHRONOSPARK-CLASS: LEGACY | Feature: Calendar/timeline
///
/// Older calendar shape used by CalendarService. Migration target is
/// CalendarEntryEntity.
/// Compatibility note: [CalendarEntry] and `CalendarEntryEntity` have identical
/// field sets. The engine (`engine/planning/calendar_service.dart`) uses this
/// one; the data layer and use cases use `CalendarEntryEntity`. `TimeBlock` is a
/// third shape with the same six fields (only `completed` vs `isCompleted`
/// differs by name).
///
/// No data is lost across these mappings today because the fields line up
/// 1:1 — but three types for one concept means a field added to one silently
/// won't exist on the others. Migration target: `CalendarEntryEntity`.
/// See `test/domain/entities/calendar_mapping_test.dart`.
class CalendarEntry {
  final String id;

  final String title;
  final String? description;

  final DateTime start;
  final DateTime end;

  final String? taskId;

  final bool isCompleted;

  CalendarEntry({
    required this.id,
    required this.title,
    this.description,
    required this.start,
    required this.end,
    this.taskId,
    this.isCompleted = false,
  });

  // ✅ Duration helper
  Duration get duration => end.difference(start);

  // ✅ Completion update
  CalendarEntry markComplete() {
    return copyWith(isCompleted: true);
  }

  // ✅ Copy for updates
  CalendarEntry copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? start,
    DateTime? end,
    String? taskId,
    bool? isCompleted,
  }) {
    return CalendarEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      start: start ?? this.start,
      end: end ?? this.end,
      taskId: taskId ?? this.taskId,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  // ✅ JSON for storage / Supabase
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "description": description,
      "start": start.toIso8601String(),
      "end": end.toIso8601String(),
      "taskId": taskId,
      "isCompleted": isCompleted,
    };
  }

  factory CalendarEntry.fromJson(Map<String, dynamic> json) {
    return CalendarEntry(
      id: (json["id"] as String?) ?? "",
      title: (json["title"] as String?) ?? "Untitled",
      description: json["description"] as String?,
      start:
          DateTime.tryParse((json["start"] as String?) ?? "") ?? DateTime.now(),
      end:
          DateTime.tryParse((json["end"] as String?) ?? "") ??
          DateTime.now().add(const Duration(hours: 24)),
      taskId: json["taskId"] as String?,
      isCompleted: (json["isCompleted"] as bool?) ?? false,
    );
  }
}
