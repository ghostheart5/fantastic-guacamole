class UserStateTracker {
  const UserStateTracker();

  Map<String, dynamic> snapshot({
    required String mood,
    required String intent,
    required double confidence,
    required List<String> recentSignals,
  }) {
    return <String, dynamic>{
      'mood': mood,
      'intent': intent,
      'confidence': confidence,
      'recent_signals': recentSignals,
      'stability': confidence >= 0.7 ? 'stable' : 'volatile',
    };
  }
}
