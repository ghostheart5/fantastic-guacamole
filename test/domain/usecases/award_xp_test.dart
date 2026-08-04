import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:fantastic_guacamole/domain/usecases/award_xp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AwardXp', () {
    late _FakeProgressionRepository repository;

    setUp(() => repository = _FakeProgressionRepository());

    test('accumulates XP and persists the result', () async {
      repository.progression = const ProgressionEntity(xp: 10);

      final ProgressionEntity updated = await AwardXp(repository).call(15);

      expect(updated.xp, 25);
      expect(repository.progression?.xp, 25);
    });

    test('crossing a threshold increases the level', () async {
      // ProgressionPolicy: level 2 begins at 100 cumulative XP.
      repository.progression = const ProgressionEntity(xp: 90, level: 1);

      final ProgressionEntity updated = await AwardXp(repository).call(10);

      expect(updated.xp, 100);
      expect(updated.level, 2);
      expect(repository.progression?.level, 2);
    });

    test('level tracks the policy curve across several thresholds', () async {
      repository.progression = const ProgressionEntity();
      final AwardXp awardXp = AwardXp(repository);

      await awardXp.call(99);
      expect(repository.progression?.level, 1, reason: '99 XP is still level 1');

      await awardXp.call(1); // 100
      expect(repository.progression?.level, 2);

      await awardXp.call(300); // 400
      expect(repository.progression?.level, 3);

      await awardXp.call(500); // 900
      expect(repository.progression?.level, 4);

      expect(
        repository.progression?.level,
        ProgressionPolicy.levelFromXp(repository.progression!.xp),
        reason: 'persisted level must always equal the policy result',
      );
    });

    test('XP stays cumulative and is never reset on level-up', () async {
      repository.progression = const ProgressionEntity(xp: 95);

      await AwardXp(repository).call(10);

      expect(repository.progression?.xp, 105);
    });

    test('rejects a negative award without touching storage', () async {
      repository.progression = const ProgressionEntity(xp: 40);

      await expectLater(() => AwardXp(repository).call(-1), throwsArgumentError);

      expect(repository.progression?.xp, 40);
      expect(repository.saveCount, 0);
    });

    test('starts from a default progression when none is stored', () async {
      final ProgressionEntity updated = await AwardXp(
        repository,
      ).call(ProgressionPolicy.taskXp);

      expect(updated.xp, ProgressionPolicy.taskXp);
      expect(updated.level, 1);
    });
  });

  group('ProgressionEntity.awardXp', () {
    test('derives level from ProgressionPolicy', () {
      const ProgressionEntity start = ProgressionEntity(xp: 0, level: 1);

      expect(start.awardXp(0).level, 1);
      expect(start.awardXp(100).level, 2);
      expect(start.awardXp(400).level, 3);
      expect(start.awardXp(1600).level, 5);
    });

    test('xpToNextLevel delegates to the canonical curve', () {
      const ProgressionEntity progression = ProgressionEntity(xp: 100);

      expect(progression.xpToNextLevel, ProgressionPolicy.xpToNextLevel(100));
      expect(progression.xpToNextLevel, 300);
    });

    test('rejects negative awards', () {
      expect(
        () => const ProgressionEntity().awardXp(-5),
        throwsArgumentError,
      );
    });
  });
}

class _FakeProgressionRepository implements IProgressionRepository {
  ProgressionEntity? progression;
  int saveCount = 0;

  @override
  Future<ProgressionEntity?> getProgression() async => progression;

  @override
  Future<void> saveProgression(ProgressionEntity progression) async {
    saveCount++;
    this.progression = progression;
  }
}
