class MemoryEntity {
  const MemoryEntity({
    required this.id,
    required this.text,
    required this.date,
    this.starred = false,
  });

  final String id;
  final String text;
  final DateTime date;
  final bool starred;

  MemoryEntity copyWith({bool? starred}) => MemoryEntity(
    id: id,
    text: text,
    date: date,
    starred: starred ?? this.starred,
  );

  // Domain behavior
  Duration get age => DateTime.now().difference(date);

  bool get isRecent => age.inDays < 3;

  MemoryEntity star() => copyWith(starred: true);

  MemoryEntity unstar() => copyWith(starred: false);

  bool contains(String query) =>
      text.toLowerCase().contains(query.toLowerCase());

  void validate() {
    if (text.trim().isEmpty) {
      throw StateError('MemoryEntity must have non-empty text');
    }
  }

  // Serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'date': date.toIso8601String(),
    'starred': starred,
  };

  factory MemoryEntity.fromJson(Map<String, dynamic> j) => MemoryEntity(
    id: j['id'] as String,
    text: j['text'] as String,
    date: DateTime.parse(j['date'] as String),
    starred: j['starred'] as bool? ?? false,
  );
}
