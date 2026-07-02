class Task {
  final String id;
  final String title;
  final int priority;
  final int difficulty;
  final int energyRequired;

  const Task({
    required this.id,
    required this.title,
    required this.priority,
    required this.difficulty,
    required this.energyRequired,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Untitled',
      priority: (json['priority'] as num?)?.toInt() ?? 3,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 3,
      energyRequired: (json['energyRequired'] as num?)?.toInt() ?? 3,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'priority': priority,
    'difficulty': difficulty,
    'energyRequired': energyRequired,
  };
}
