import 'package:fantastic_guacamole/core/debug/app_analytics.dart';

class ContentGenerationAnalytics {
  const ContentGenerationAnalytics._();

  static void trackRouteResolved({
    required String surface,
    required String intent,
    required String routeType,
    required bool forcedSurface,
    required int matchedSurfaceCount,
  }) {
    AppAnalytics.track(
      'content_route_resolved',
      params: <String, Object?>{
        'surface': _safeValue(surface),
        'intent': _safeValue(intent),
        'route_type': _safeValue(routeType),
        'forced_surface': forcedSurface,
        'matched_surfaces': matchedSurfaceCount,
      },
    );
  }

  static void trackResult({
    required String surface,
    required String routeType,
    required bool usedFallback,
    required bool structured,
    required int durationMs,
    String qualityTag = 'normal',
  }) {
    AppAnalytics.track(
      'content_result',
      params: <String, Object?>{
        'surface': _safeValue(surface),
        'route_type': _safeValue(routeType),
        'used_fallback': usedFallback,
        'structured': structured,
        'duration_ms': durationMs,
        'quality_tag': _safeValue(qualityTag),
      },
    );
  }

  static String _safeValue(String value) {
    final String normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'unknown';
    }
    return normalized.length > 64 ? normalized.substring(0, 64) : normalized;
  }
}
