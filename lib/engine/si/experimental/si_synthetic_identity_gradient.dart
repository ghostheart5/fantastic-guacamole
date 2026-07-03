class IdentityGradient {
  const IdentityGradient({
    required this.anchorPersona,
    required this.gradientPersona,
    required this.shift,
    required this.relationshipDepth,
  });

  final String anchorPersona;
  final String gradientPersona;
  final double shift;
  final double relationshipDepth;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'anchor_persona': anchorPersona,
      'gradient_persona': gradientPersona,
      'shift': shift,
      'relationship_depth': relationshipDepth,
    };
  }
}

class SyntheticIdentityGradient {
  const SyntheticIdentityGradient();

  IdentityGradient resolve({
    required String basePersona,
    required String mood,
    required String intent,
    required String appContext,
    required int historyDepth,
  }) {
    final double relationshipDepth = (historyDepth / 40).clamp(0.0, 1.0);
    final double shift =
        ((mood == 'stressed' ? 0.22 : 0.1) +
                (intent == 'insight_request' ? 0.2 : 0.08) +
                (appContext.contains('chrono') ? 0.16 : 0.06) +
                relationshipDepth * 0.32)
            .clamp(0.0, 1.0);

    final String gradient = shift > 0.65
        ? '${basePersona}_adaptive_guardian'
        : shift > 0.45
        ? '${basePersona}_adaptive_strategist'
        : '${basePersona}_stable_companion';

    return IdentityGradient(
      anchorPersona: basePersona,
      gradientPersona: gradient,
      shift: shift,
      relationshipDepth: relationshipDepth,
    );
  }
}
