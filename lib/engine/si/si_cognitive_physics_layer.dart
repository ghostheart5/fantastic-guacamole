class CognitivePhysicsState {
  const CognitivePhysicsState({
    required this.cognitiveMomentum,
    required this.emotionalInertia,
    required this.intentGravity,
    required this.memoryFriction,
    required this.personaElasticity,
  });

  final double cognitiveMomentum;
  final double emotionalInertia;
  final double intentGravity;
  final double memoryFriction;
  final double personaElasticity;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'cognitive_momentum': cognitiveMomentum,
      'emotional_inertia': emotionalInertia,
      'intent_gravity': intentGravity,
      'memory_friction': memoryFriction,
      'persona_elasticity': personaElasticity,
    };
  }
}

class CognitivePhysicsLayer {
  const CognitivePhysicsLayer();

  CognitivePhysicsState simulate({
    required String mood,
    required double confidence,
    required double urgency,
    required int historyDepth,
  }) {
    final double emotionalInertia = mood == 'stressed' ? 0.78 : 0.52;
    final double memoryFriction = (0.25 + historyDepth / 260).clamp(0.0, 1.0);
    final double cognitiveMomentum =
        ((confidence * 0.65) + (1 - memoryFriction) * 0.35).clamp(0.0, 1.0);
    final double intentGravity = (urgency * 0.7 + confidence * 0.3).clamp(
      0.0,
      1.0,
    );
    final double personaElasticity = (0.85 - emotionalInertia * 0.4).clamp(
      0.0,
      1.0,
    );
    return CognitivePhysicsState(
      cognitiveMomentum: cognitiveMomentum,
      emotionalInertia: emotionalInertia,
      intentGravity: intentGravity,
      memoryFriction: memoryFriction,
      personaElasticity: personaElasticity,
    );
  }
}
