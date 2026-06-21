class SIEmotion {
  double level = 0.5;

  void update(double delta) {
    level = (level + delta).clamp(0, 1);
  }
}
