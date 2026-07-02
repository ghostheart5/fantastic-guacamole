class MemoryEcho {
  const MemoryEcho({
    required this.faint,
    required this.strong,
    required this.emotional,
    required this.temporal,
    required this.contextual,
    required this.predictedNeed,
  });

  final List<String> faint;
  final List<String> strong;
  final List<String> emotional;
  final List<String> temporal;
  final List<String> contextual;
  final String predictedNeed;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'faint': faint,
      'strong': strong,
      'emotional': emotional,
      'temporal': temporal,
      'contextual': contextual,
      'predicted_need': predictedNeed,
    };
  }
}

class SyntheticMemoryEchoLayer {
  const SyntheticMemoryEchoLayer();

  MemoryEcho echo({
    required List<String> history,
    required String mood,
    required String intent,
  }) {
    final List<String> faint = history
        .where((String h) => h.length < 28)
        .take(2)
        .toList();
    final List<String> strong = history
        .where((String h) => h.toLowerCase().contains('focus'))
        .take(3)
        .toList();
    return MemoryEcho(
      faint: faint,
      strong: strong,
      emotional: <String>[if (mood == 'stressed') 'stress_echo'],
      temporal: <String>[if (intent == 'reflect') 'reflection_echo'],
      contextual: <String>[if (intent == 'get_task') 'execution_echo'],
      predictedNeed: strong.isNotEmpty
          ? 'structured_next_step'
          : 'clarification',
    );
  }
}
