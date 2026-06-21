class DetectTimeFracturesUseCase {
  bool call({
    required double focusScore,
    required int overloadedNodes,
    required double boost,
  }) {
    return focusScore > 0.8 || overloadedNodes >= 2 || boost > 0.35;
  }
}
