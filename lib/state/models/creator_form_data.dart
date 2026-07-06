class CreatorFormData {
  const CreatorFormData({
    required this.title,
    this.description,
    required this.type,
    required this.priority,
    this.scheduledFor,
  });

  final String title;
  final String? description;
  final String type;
  final int priority;
  final DateTime? scheduledFor;
}
