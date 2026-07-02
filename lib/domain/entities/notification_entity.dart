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
}
