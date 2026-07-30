class NotificationEntity {
  const NotificationEntity({
    required this.id,
    required this.title,
    required this.message,
    required this.scheduledAt,
    this.isEnabled = true,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String message;
  final DateTime scheduledAt;
  final bool isEnabled;
  final bool isRead;

  // Domain behavior
  bool get isDue => DateTime.now().isAfter(scheduledAt);

  Duration get timeUntil => scheduledAt.difference(DateTime.now());

  NotificationEntity enable() => copyWith(isEnabled: true);

  NotificationEntity disable() => copyWith(isEnabled: false);

  NotificationEntity markRead() => copyWith(isRead: true);

  NotificationEntity markUnread() => copyWith(isRead: false);

  bool contains(String query) {
    final q = query.toLowerCase();
    return title.toLowerCase().contains(q) || message.toLowerCase().contains(q);
  }

  void validate() {
    if (title.trim().isEmpty) {
      throw StateError('NotificationEntity must have a title');
    }
  }

  NotificationEntity copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? scheduledAt,
    bool? isEnabled,
    bool? isRead,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      isEnabled: isEnabled ?? this.isEnabled,
      isRead: isRead ?? this.isRead,
    );
  }
}
