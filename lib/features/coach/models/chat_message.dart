enum ChatAuthor { coach, user }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final ChatAuthor author;
  final String text;
  final DateTime createdAt;
}
