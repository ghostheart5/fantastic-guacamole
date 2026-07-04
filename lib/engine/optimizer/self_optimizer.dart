import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/engine/advisor/product_advisor_engine.dart';
import 'package:fantastic_guacamole/engine/optimizer/optimization_config.dart';

class SelfOptimizer {
  const SelfOptimizer();

  static const _kConfigKey = 'self_opt_config_v1';
  static const _kLastAdjustKey = 'self_opt_last_adjust';

  OptimizationConfig adjust(
    OptimizationConfig current,
    List<ProductInsight> insights,
  ) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastAdjust = SharedPrefsService.load(_kLastAdjustKey);

    if (lastAdjust == today) {
      return _loadStored() ?? current;
    }

    // No issues or fallback — persist current and return
    if (insights.isEmpty ||
        insights.first.issue == 'No major issues detected' ||
        insights.first.issue == 'Not enough data yet') {
      unawaited(_persistConfig(current, today));
      return current;
    }

    var focusMult = current.focusDurationMultiplier;
    var diffScale = current.taskDifficultyScale;
    var aggression = current.nextActionAggressiveness;

    for (final insight in insights) {
      if (insight.issue.contains('Focus sessions abandoned') ||
          insight.issue.contains('Focus completion rate')) {
        focusMult = (focusMult * 0.9).clamp(0.5, 1.5);
      }
      if (insight.issue.contains("don't start")) {
        aggression = (aggression * 0.9).clamp(0.5, 1.5);
      }
      if (insight.issue.contains('Low momentum') ||
          insight.issue.contains('not completed')) {
        diffScale = (diffScale * 0.85).clamp(0.5, 1.5);
        aggression = (aggression * 0.9).clamp(0.5, 1.5);
      }
    }

    final adjusted = OptimizationConfig(
      focusDurationMultiplier: focusMult,
      taskDifficultyScale: diffScale,
      nextActionAggressiveness: aggression,
    );
    unawaited(_persistConfig(adjusted, today));
    return adjusted;
  }

  OptimizationConfig? _loadStored() {
    final raw = SharedPrefsService.load(_kConfigKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return OptimizationConfig(
        focusDurationMultiplier:
            (json['focusDurationMultiplier'] as num?)?.toDouble() ?? 1.0,
        taskDifficultyScale:
            (json['taskDifficultyScale'] as num?)?.toDouble() ?? 1.0,
        nextActionAggressiveness:
            (json['nextActionAggressiveness'] as num?)?.toDouble() ?? 1.0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistConfig(OptimizationConfig config, String date) async {
    await SharedPrefsService.save(_kLastAdjustKey, date);
    await SharedPrefsService.save(
      _kConfigKey,
      jsonEncode({
        'focusDurationMultiplier': config.focusDurationMultiplier,
        'taskDifficultyScale': config.taskDifficultyScale,
        'nextActionAggressiveness': config.nextActionAggressiveness,
      }),
    );
  }
}
