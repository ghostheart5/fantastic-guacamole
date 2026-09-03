import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no production path silently mirrors signal output into memory', () {
    final String signals = File(
      'lib/state/providers/signals_provider.dart',
    ).readAsStringSync();
    final Iterable<File> productionFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'));

    expect(signals, isNot(contains('saveMirroredMemory')));
    expect(signals, isNot(contains('memoriesActionsProvider')));
    for (final File file in productionFiles) {
      final String source = file.readAsStringSync();
      expect(
        source,
        isNot(contains('saveMirroredMemory')),
        reason: 'Hidden memory hook in ${file.path}',
      );
    }
  });

  test('durable memory UI requires consent and exposes receipts', () {
    final String planner = File(
      'lib/features/home/ui/smart_planner_screen.dart',
    ).readAsStringSync();
    final String settings = File(
      'lib/features/settings/ui/settings_screen.governance_sections.dart',
    ).readAsStringSync();

    expect(planner, contains("Key('planner-memory-consent')"));
    expect(planner, contains("Key('planner-confirm-memory')"));
    expect(planner, contains('Use only this time'));
    expect(planner, contains('consentConfirmed: true'));
    expect(settings, contains('Review memory receipts'));
    expect(settings, contains('Export memory receipts'));
    expect(settings, contains('Delete all durable memories'));
    expect(settings, contains('correct, export, delete'));
    expect(settings, isNot(contains('exportAllStates')));
  });

  test('assistant aggregation cannot bridge global memory content', () {
    final String pipeline = File(
      'lib/state/providers/si_pipeline_provider.dart',
    ).readAsStringSync();
    final String controller = File(
      'lib/state/controllers/ai_controller.dart',
    ).readAsStringSync();
    final String profile = File(
      'lib/state/models/personalization_models.dart',
    ).readAsStringSync();

    expect(pipeline, isNot(contains('ref.watch(memoriesProvider)')));
    expect(
      controller,
      contains('memoryRecallProvider(MemorySurface.siConsole)'),
    );
    expect(profile, contains('this.useMemoryContext = false'));
    expect(profile, contains('storedVersion >= currentVersion'));
    expect(profile, contains('memoryConsentGrantedAt'));
  });

  test('session context is surface-scoped and expires within 24 hours', () {
    final String repository = File(
      'lib/data/repositories/si_engine_repository.dart',
    ).readAsStringSync();

    expect(repository, contains('sessionRetention = Duration(hours: 24)'));
    expect(repository, contains('sessionExpiresAtUtc'));
    expect(repository, contains('conversation.surface.storageId'));
    expect(repository, contains('accountNamespace'));
  });
}
