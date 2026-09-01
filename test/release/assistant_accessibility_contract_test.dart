import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Smart Planner exposes Phase 10 semantic and recovery contracts', () {
    final String source = File(
      'lib/features/home/ui/smart_planner_screen.dart',
    ).readAsStringSync();

    expect(source, contains("label: 'Planning context'"));
    expect(source, contains("label: 'Current energy'"));
    expect(source, contains("label: 'Planning guidance ready'"));
    expect(source, contains("label: 'Follow-up failed. \$errorText'"));
    expect(source, contains("labelText: 'Follow-up question'"));
    expect(source, contains('liveRegion: true'));
    expect(
      source,
      contains('? null\n                          : _getPlanningGuidance'),
    );
    expect(source, isNot(contains('TextScaler.noScaling')));
  });

  test('SI V2 exposes live status, named input, and large-text reflow', () {
    final String source = File(
      'lib/features/si_console/ui/si_console_screen.dart',
    ).readAsStringSync();

    expect(source, contains("labelText: 'SI query'"));
    expect(
      source,
      contains(
        RegExp(
          r"label:\s*!enabled\s*\?\s*'SI Console unavailable'\s*:\s*busy\s*\?\s*'SI is analyzing'\s*:\s*'Send SI query'",
        ),
      ),
    );
    expect(source, contains("label: isUser ? 'Your query' : 'SI response'"));
    expect(source, contains('MediaQuery.textScalerOf(context).scale(1) > 1.3'));
    expect(source, contains('Retry evidence loading'));
    expect(source, contains("label: 'SI is analyzing the current evidence'"));
    expect(source, isNot(contains('TextScaler.noScaling')));
  });

  test('shared custom controls preserve semantic actions and target sizes', () {
    final String pressable = File(
      'lib/ui/widgets/smart_pressable.dart',
    ).readAsStringSync();
    final String button = File(
      'lib/ui/widgets/holo_button.dart',
    ).readAsStringSync();
    final String emotion = File(
      'lib/features/emotion/widgets/emotion_selector.dart',
    ).readAsStringSync();

    expect(pressable, contains('onTap: () => unawaited(_handleTap())'));
    expect(pressable, contains('selected: widget.selected'));
    expect(button, contains('enabled: widget.onTap != null'));
    expect(button, contains('minWidth: 48, minHeight: 48'));
    expect(emotion, contains('minHeight: 48, minWidth: 48'));
    expect(emotion, contains("semanticLabel: 'Select \${state.name}"));
  });
}
