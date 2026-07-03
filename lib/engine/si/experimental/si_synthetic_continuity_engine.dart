class ContinuityState {
  const ContinuityState({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.crossApp,
    required this.crossRealm,
    required this.crossPersona,
    required this.index,
  });

  final double daily;
  final double weekly;
  final double monthly;
  final double crossApp;
  final double crossRealm;
  final double crossPersona;
  final double index;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'daily': daily,
      'weekly': weekly,
      'monthly': monthly,
      'cross_app': crossApp,
      'cross_realm': crossRealm,
      'cross_persona': crossPersona,
      'index': index,
    };
  }
}

class SyntheticContinuityEngine {
  const SyntheticContinuityEngine();

  ContinuityState evaluate({
    required int historyDepth,
    required bool sameRealm,
  }) {
    final double daily = (0.5 + historyDepth / 80).clamp(0.0, 1.0);
    final double weekly = (0.42 + historyDepth / 120).clamp(0.0, 1.0);
    final double monthly = (0.35 + historyDepth / 180).clamp(0.0, 1.0);
    final double crossRealm = sameRealm ? 0.58 : 0.76;
    final double crossPersona = (0.52 + historyDepth / 150).clamp(0.0, 1.0);
    final double index =
        ((daily + weekly + monthly + 0.65 + crossRealm + crossPersona) / 6)
            .clamp(0.0, 1.0);
    return ContinuityState(
      daily: daily,
      weekly: weekly,
      monthly: monthly,
      crossApp: 0.65,
      crossRealm: crossRealm,
      crossPersona: crossPersona,
      index: index,
    );
  }
}
