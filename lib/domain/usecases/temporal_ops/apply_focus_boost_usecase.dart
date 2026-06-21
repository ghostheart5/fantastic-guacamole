class ApplyFocusBoostUseCase {
  List<double> call(List<double> values, double boost) {
    return values
        .map((double v) => (v + boost).clamp(0.0, 1.0))
        .cast<double>()
        .toList();
  }
}
