/// Persisted habit shape shared by the domain contract and data repository.
class HabitRecord {
  const HabitRecord({
    required this.id,
    required this.title,
    this.active = true,
  });

  final String id;
  final String title;
  final bool active;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'active': active,
  };

  factory HabitRecord.fromJson(Map<String, dynamic> json) {
    return HabitRecord(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      active: json['active'] as bool? ?? true,
    );
  }
}
