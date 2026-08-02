class AuthNotificationTrigger {
  const AuthNotificationTrigger({
    required this.code,
    required this.title,
    required this.body,
    this.userId,
    this.data = const <String, Object?>{},
  });

  final String code;
  final String title;
  final String body;
  final String? userId;
  final Map<String, Object?> data;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'code': code,
      'title': title,
      'body': body,
      'userId': userId,
      'data': data,
    };
  }
}
