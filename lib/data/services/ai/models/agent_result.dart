class AgentResult {
  const AgentResult({
    required this.selectedAgent,
    required this.workflow,
    required this.payload,
  });

  final String selectedAgent;
  final String workflow;
  final Map<String, dynamic> payload;

  String get message => payload['message']?.toString() ?? '';
  String get reasoning => payload['reasoning']?.toString() ?? message;
  String get emotion => payload['emotion']?.toString() ?? 'balanced';
  String get mode => payload['mode']?.toString() ?? 'unknown';
  double get confidence => (payload['confidence'] as num?)?.toDouble() ?? 0.5;
  int get durationMs => (payload['durationMs'] as num?)?.toInt() ?? 0;
  Map<String, dynamic>? get taskMap => payload['task'] as Map<String, dynamic>?;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'selectedAgent': selectedAgent,
    'workflow': workflow,
    'payload': payload,
  };
}
