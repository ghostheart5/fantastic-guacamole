class MetaPersona {
  const MetaPersona({
    required this.name,
    required this.traits,
    required this.reason,
  });

  final String name;
  final List<String> traits;
  final String reason;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'name': name, 'traits': traits, 'reason': reason};
  }
}

class CognitiveMetaPersonaEngine {
  const CognitiveMetaPersonaEngine();

  MetaPersona synthesize({
    required String mood,
    required String taskType,
    required String realm,
    required int historyDepth,
  }) {
    final String name = '${realm}_meta_${taskType}_$mood'
        .replaceAll(' ', '_')
        .toLowerCase();
    return MetaPersona(
      name: name,
      traits: <String>[
        if (mood == 'stressed') 'calming',
        if (taskType == 'insight_request') 'diagnostic',
        if (historyDepth > 10) 'continuity-aware',
        'adaptive',
      ],
      reason:
          'Generated from mood, task type, realm, and long-term interaction depth.',
    );
  }
}
