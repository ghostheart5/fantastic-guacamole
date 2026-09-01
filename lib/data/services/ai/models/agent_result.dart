class AgentResult {
  AgentResult({
    required this.selectedAgent,
    required this.workflow,
    required Map<String, dynamic> payload,
  }) : payload = Map<String, dynamic>.unmodifiable(
         payload.map<String, dynamic>(
           (String key, dynamic value) => MapEntry(key, _freezeValue(value)),
         ),
       );

  final String selectedAgent;
  final String workflow;
  final Map<String, dynamic> payload;

  static dynamic _freezeValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.unmodifiable(
        value.map<String, dynamic>(
          (String key, dynamic item) => MapEntry(key, _freezeValue(item)),
        ),
      );
    }
    if (value is Map) {
      return Map<Object?, Object?>.unmodifiable(
        value.map<Object?, Object?>(
          (dynamic key, dynamic item) => MapEntry(key, _freezeValue(item)),
        ),
      );
    }
    if (value is List<String>) {
      return List<String>.unmodifiable(value);
    }
    if (value is Iterable) {
      return List<Object?>.unmodifiable(value.map(_freezeValue));
    }
    return value;
  }

  String get message => payload['message']?.toString() ?? '';
  String get reasoning => payload['reasoning']?.toString() ?? message;
  String get emotion => payload['emotion']?.toString() ?? 'balanced';
  String get mode => payload['mode']?.toString() ?? 'unknown';
  double get confidence => (payload['confidence'] as num?)?.toDouble() ?? 0.5;
  int get durationMs => (payload['durationMs'] as num?)?.toInt() ?? 0;
  bool get usedDefaults => payload['usedDefaults'] == true;
  String get source => payload['source']?.toString() ?? 'local';
  bool get modelBacked => payload['modelBacked'] == true;
  List<String> get defaultedFields =>
      (payload['defaultedFields'] as List<dynamic>?)
          ?.map((dynamic v) => v.toString())
          .toList(growable: false) ??
      const <String>[];
  String get quality => payload['quality']?.toString() ?? 'unknown';
  Map<String, dynamic>? get taskMap {
    final Object? task = payload['task'];
    if (task is! Map) {
      return null;
    }
    return Map<String, dynamic>.unmodifiable(
      task.map<String, dynamic>(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'selectedAgent': selectedAgent,
    'workflow': workflow,
    'payload': Map<String, dynamic>.from(payload),
  };
}
