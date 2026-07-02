import 'dart:async';

import 'package:fantastic_guacamole/core/services/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FeedbackService {
  static Future<void> tap({required bool soundEnabled}) async {
    HapticFeedback.lightImpact();
    await AudioService.play('audio/error_soft.wav', soundEnabled);
  }

  static Future<void> success(BuildContext context, {required bool soundEnabled}) async {
    HapticFeedback.mediumImpact();
    await AudioService.play('audio/task_complete.wav', soundEnabled);
  }

  static Future<void> streakWarning({required bool soundEnabled}) async {
    HapticFeedback.heavyImpact();
    await AudioService.play('audio/error_soft.wav', soundEnabled);
  }

  static Future<void> taskComplete({required bool soundEnabled}) async {
    HapticFeedback.mediumImpact();
    await AudioService.play('audio/task_complete.wav', soundEnabled);
  }

  static Future<void> focusStart({required bool soundEnabled}) async {
    HapticFeedback.selectionClick();
    await AudioService.play('audio/focus_start.wav', soundEnabled);
  }

  static Future<void> aiDecision({required bool soundEnabled}) async {
    HapticFeedback.selectionClick();
    await AudioService.play('audio/ai_decision.wav', soundEnabled);
  }

  static Future<void> tapThenAction(
    FutureOr<void> Function() action, {
    required bool soundEnabled,
  }) async {
    await tap(soundEnabled: soundEnabled);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await Future<void>.sync(action);
  }
}
