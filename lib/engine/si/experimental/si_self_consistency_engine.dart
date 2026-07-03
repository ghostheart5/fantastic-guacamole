class SelfConsistencyReport {
  const SelfConsistencyReport({
    required this.consistent,
    required this.toneMismatch,
    required this.personaMismatch,
    required this.identityMismatch,
    required this.notes,
  });

  final bool consistent;
  final bool toneMismatch;
  final bool personaMismatch;
  final bool identityMismatch;
  final List<String> notes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'consistent': consistent,
      'tone_mismatch': toneMismatch,
      'persona_mismatch': personaMismatch,
      'identity_mismatch': identityMismatch,
      'notes': notes,
    };
  }
}

class SelfConsistencyEngine {
  const SelfConsistencyEngine();

  SelfConsistencyReport evaluate({
    required String mood,
    required String persona,
    required String identityTone,
    required String outputMode,
    required Map<String, dynamic> previousSnapshot,
  }) {
    final String? prevMood = previousSnapshot['mood']?.toString();
    final String? prevPersona = previousSnapshot['persona']?.toString();

    final bool toneMismatch =
        prevMood != null && prevMood != mood && mood == 'motivational';
    final bool personaMismatch = prevPersona != null && prevPersona != persona;
    final bool identityMismatch =
        outputMode == 'technical' && identityTone == 'mystic';

    return SelfConsistencyReport(
      consistent: !(toneMismatch || personaMismatch || identityMismatch),
      toneMismatch: toneMismatch,
      personaMismatch: personaMismatch,
      identityMismatch: identityMismatch,
      notes: <String>[
        if (toneMismatch) 'Tone drift detected. Prefer smoother transition.',
        if (personaMismatch) 'Persona changed; provide continuity cue.',
        if (identityMismatch) 'Identity tone conflicts with output mode.',
      ],
    );
  }
}
