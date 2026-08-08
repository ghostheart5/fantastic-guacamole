import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_learning_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/policies/learning_policy.dart';
import 'package:fantastic_guacamole/domain/usecases/apply_learning_feedback.dart';
import 'package:fantastic_guacamole/domain/usecases/update_learning_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the learning loop. The repository is now implemented and DI-bound, so
/// LearningPolicy is reachable — but nothing invokes it automatically yet.
/// See the PLANNED note on [ILearningRepository].
void main() {
  group('ApplyLearningFeedback moves the weights', () {
    late _FakeLearningRepository repository;

    setUp(() => repository = _FakeLearningRepository());

    test('success raises effortWeight and increments completed', () async {
      repository.state = const LearningEntity();

      final LearningEntity updated = await ApplyLearningFeedback(
        repository,
      ).call(success: true, difficulty: 3);

      expect(updated.effortWeight, closeTo(1.05, 1e-9));
      expect(updated.completed, 1);
      expect(updated.skipped, 0);
      expect(repository.state, same(updated), reason: 'persisted');
    });

    test('failure lowers effortWeight and increments skipped', () async {
      repository.state = const LearningEntity();

      final LearningEntity updated = await ApplyLearningFeedback(
        repository,
      ).call(success: false, difficulty: 3);

      expect(updated.effortWeight, closeTo(0.95, 1e-9));
      expect(updated.completed, 0);
      expect(updated.skipped, 1);
    });

    test('hard tasks additionally move priorityWeight', () async {
      repository.state = const LearningEntity();

      final LearningEntity updated = await ApplyLearningFeedback(
        repository,
      ).call(success: true, difficulty: 5);

      expect(updated.priorityWeight, closeTo(1.03, 1e-9));
    });

    test('easy tasks leave priorityWeight untouched', () async {
      repository.state = const LearningEntity();

      final LearningEntity updated = await ApplyLearningFeedback(
        repository,
      ).call(success: true, difficulty: 2);

      expect(updated.priorityWeight, 1.0);
    });

    test('weights are clamped to the policy bounds', () async {
      repository.state = const LearningEntity(effortWeight: 2.0);

      final LearningEntity updated = await ApplyLearningFeedback(
        repository,
      ).call(success: true, difficulty: 3);

      expect(updated.effortWeight, 2.0, reason: 'clamped at the upper bound');

      repository.state = const LearningEntity(effortWeight: 0.5);
      final LearningEntity lowered = await ApplyLearningFeedback(
        repository,
      ).call(success: false, difficulty: 3);

      expect(lowered.effortWeight, 0.5, reason: 'clamped at the lower bound');
    });

    test('starts from defaults when no state is stored', () async {
      final LearningEntity updated = await ApplyLearningFeedback(
        repository,
      ).call(success: true, difficulty: 3);

      expect(updated.completed, 1);
      expect(updated.effortWeight, closeTo(1.05, 1e-9));
    });

    test('a success nudges SI confidence upward', () async {
      final _FakeSiRepository siRepo = _FakeSiRepository(
        SiStateEntity(energy: 0.6, focus: 0.5, fatigue: 0.3, confidence: 0.5),
      );

      await ApplyLearningFeedback(
        repository,
        siRepo: siRepo,
      ).call(success: true, difficulty: 3);

      expect(siRepo.saved?.confidence, greaterThan(0.5));
    });

    test('feedback accumulates across calls', () async {
      final ApplyLearningFeedback applyFeedback = ApplyLearningFeedback(
        repository,
      );

      await applyFeedback.call(success: true, difficulty: 3);
      await applyFeedback.call(success: true, difficulty: 3);
      final LearningEntity updated = await applyFeedback.call(
        success: false,
        difficulty: 3,
      );

      expect(updated.completed, 2);
      expect(updated.skipped, 1);
    });
  });

  group('LearningPolicy is reachable and deterministic', () {
    test('applyFeedback is a pure function of its inputs', () {
      const LearningEntity current = LearningEntity();

      final LearningEntity a = LearningPolicy.applyFeedback(
        current: current,
        success: true,
        difficulty: 4,
      );
      final LearningEntity b = LearningPolicy.applyFeedback(
        current: current,
        success: true,
        difficulty: 4,
      );

      expect(a.effortWeight, b.effortWeight);
      expect(a.priorityWeight, b.priorityWeight);
      expect(a.completed, b.completed);
    });
  });

  group('UpdateLearningState', () {
    test('persists the supplied state verbatim', () async {
      final _FakeLearningRepository repository = _FakeLearningRepository();
      const LearningEntity state = LearningEntity(
        effortWeight: 1.4,
        priorityWeight: 0.8,
        completed: 7,
        skipped: 2,
      );

      await UpdateLearningState(repository).call(state);

      expect(repository.state?.effortWeight, 1.4);
      expect(repository.state?.priorityWeight, 0.8);
      expect(repository.state?.completed, 7);
      expect(repository.state?.skipped, 2);
    });
  });
}

class _FakeLearningRepository implements ILearningRepository {
  LearningEntity? state;

  @override
  Future<LearningEntity?> getState() async => state;

  @override
  Future<void> saveState(LearningEntity state) async => this.state = state;
}

class _FakeSiRepository implements ISiRepository {
  _FakeSiRepository(this._state);

  final SiStateEntity? _state;
  SiStateEntity? saved;

  @override
  Future<SiStateEntity?> getCurrentState() async => saved ?? _state;

  @override
  Future<void> saveState(SiStateEntity state) async => saved = state;
}
