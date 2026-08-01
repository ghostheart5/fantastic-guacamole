import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('Goal lifecycle provider contract', () {
    test('goals provider keeps complete/archive/reopen on canonical transitions', () {
      final File providerFile = File('lib/state/providers/goals_provider.dart');
      expect(providerFile.existsSync(), isTrue);

      final String providerText = SourceTestUtils.readText(providerFile);

      expect(providerText.contains('Future<void> complete(String id) async'), isTrue);
      expect(providerText.contains('await ref.read(completeGoalUseCaseProvider).call(id);'), isTrue);
      expect(providerText.contains('selectedGoal.markCompleted()'), isTrue);
      expect(providerText.contains('state = state.where((g) => g.id != id).toList();'), isFalse);

      expect(providerText.contains('Future<void> archive(String id) async'), isTrue);
      expect(providerText.contains('await ref.read(archiveGoalUseCaseProvider).call(id);'), isTrue);
      expect(providerText.contains('selectedGoal.archive()'), isTrue);

      expect(providerText.contains('Future<void> reopen(String id) async'), isTrue);
      expect(providerText.contains('await ref.read(reopenGoalUseCaseProvider).call(id);'), isTrue);
      expect(providerText.contains('selectedGoal.activate()'), isTrue);
    });

    test('goals provider keeps delete explicit and separate from complete', () {
      final File providerFile = File('lib/state/providers/goals_provider.dart');
      expect(providerFile.existsSync(), isTrue);

      final String providerText = SourceTestUtils.readText(providerFile);

      expect(providerText.contains('Future<void> remove(String id) async'), isTrue);
      expect(providerText.contains('await ref.read(deleteGoalUseCaseProvider).call(id);'), isTrue);
      expect(providerText.contains('await complete(id);'), isFalse);
    });
  });
}
