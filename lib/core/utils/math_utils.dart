import 'dart:math';

class MathUtils {
  // -----------------------------
  // BASIC SAFE PARSING
  // -----------------------------

  static int parseInt(String? value, {int fallback = 0}) {
    if (value == null) return fallback;
    return int.tryParse(value) ?? fallback;
  }

  static double parseDouble(String? value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    return double.tryParse(value) ?? fallback;
  }

  // -----------------------------
  // CLAMPING
  // -----------------------------

  static num clamp(num value, num min, num max) {
    return value < min ? min : (value > max ? max : value);
  }

  // -----------------------------
  // ROUNDING
  // -----------------------------

  static double roundTo(double value, int decimals) {
    final factor = pow(10, decimals);
    return (value * factor).round() / factor;
  }

  static int roundUp(double value) => value.ceil();
  static int roundDown(double value) => value.floor();

  // -----------------------------
  // PERCENTAGES
  // -----------------------------

  static double percentOf(double value, double percent) {
    return value * (percent / 100);
  }

  static double percentBetween(double current, double min, double max) {
    if (max == min) return 0;
    return ((current - min) / (max - min)) * 100;
  }

  // -----------------------------
  // INTERPOLATION (LERP)
  // -----------------------------

  static double lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  static double lerpClamped(double a, double b, double t) {
    return lerp(a, b, t.clamp(0.0, 1.0));
  }

  static double inverseLerp(double a, double b, double value) {
    if (a == b) return 0;
    return (value - a) / (b - a);
  }

  /// Maps [value] from [min]..[max] to 0..1. Alias for [inverseLerp].
  static double normalize(double value, double min, double max) {
    return inverseLerp(min, max, value);
  }

  // -----------------------------
  // ANGLES
  // -----------------------------

  static double degToRad(double degrees) => degrees * (pi / 180);
  static double radToDeg(double radians) => radians * (180 / pi);

  // -----------------------------
  // VECTOR MATH
  // -----------------------------

  static double distance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return sqrt(dx * dx + dy * dy);
  }

  static double magnitude(double x, double y) {
    return sqrt(x * x + y * y);
  }

  static double dot(double ax, double ay, double bx, double by) {
    return ax * bx + ay * by;
  }

  // -----------------------------
  // RANDOM HELPERS
  // -----------------------------

  static final Random _rand = Random();

  static int randomInt(int min, int max) {
    return min + _rand.nextInt(max - min);
  }

  static double randomDouble(double min, double max) {
    return min + _rand.nextDouble() * (max - min);
  }

  static bool randomBool() => _rand.nextBool();

  // -----------------------------
  // SAFE NULL MATH
  // -----------------------------

  static num orZero(num? value) => value ?? 0;

  static num add(num? a, num? b) => (a ?? 0) + (b ?? 0);

  static num subtract(num? a, num? b) => (a ?? 0) - (b ?? 0);

  static num multiply(num? a, num? b) => (a ?? 0) * (b ?? 0);

  static num divide(num? a, num? b) {
    if (b == null || b == 0) return 0;
    return (a ?? 0) / b;
  }

  // -----------------------------
  // CHRONOSPARK TIMELINE MATH
  // -----------------------------

  /// Converts minutes into timeline block height (px).
  static double timelineHeight(int minutes, double pxPerMinute) {
    return minutes * pxPerMinute;
  }

  /// Converts pixel height back into minutes.
  static int timelineMinutes(double height, double pxPerMinute) {
    return (height / pxPerMinute).round();
  }

  /// Predicts task completion percentage based on elapsed time.
  static double taskProgress(int elapsedMinutes, int totalMinutes) {
    if (totalMinutes <= 0) return 0;
    return clamp(elapsedMinutes / totalMinutes, 0, 1).toDouble();
  }
}
