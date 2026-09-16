import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/update_level.dart';
import 'package:fantastic_guacamole/domain/usecases/update_streak.dart';
import 'package:fantastic_guacamole/domain/usecases/update_xp.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements IProgressionRepository {
  _Repository(this.value);

  ProgressionEntity? value;
  int reads = 0;
  int writes = 0;
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<ProgressionEntity?> getProgression() async {
    reads++;
    if (failRead) throw StateError('Stored progression unavailable');
    return value;
  }

  @override
  Future<void> saveProgression(ProgressionEntity progression) async {
    writes++;
    if (failWrite) throw StateError('Progression storage unavailable');
    value = progression;
  }
}

void main() {
  const ProgressionEntity original = ProgressionEntity(
    xp: 900,
    level: 4,
    streak: 7,
  );

  test(
    'XP import replaces the absolute total and recomputes its level',
    () async {
      final _Repository repository = _Repository(original);
      final ProgressionEntity restored = await UpdateXp(repository)(400);

      expect(restored.xp, 400);
      expect(restored.level, 3);
      expect(restored.streak, 7);
      expect(repository.value, same(restored));
      expect(repository.writes, 1);
      expect(original.xp, 900);
    },
  );

  test(
    'zero XP restore initializes an absent profile without a reward',
    () async {
      final _Repository repository = _Repository(null);
      final ProgressionEntity restored = await UpdateXp(repository)(0);

      expect(restored.xp, 0);
      expect(restored.level, 1);
      expect(restored.streak, 0);
      expect(repository.value, same(restored));
    },
  );

  test(
    'administrative level correction preserves earned XP and streak',
    () async {
      final _Repository repository = _Repository(
        const ProgressionEntity(xp: 900, level: 2, streak: 7),
      );
      final ProgressionEntity restored = await UpdateLevel(repository)(4);

      expect(restored.level, 4);
      expect(restored.xp, 900);
      expect(restored.streak, 7);
      expect(repository.value, same(restored));
    },
  );

  test('streak reset preserves cumulative XP and earned level', () async {
    final _Repository repository = _Repository(original);
    final ProgressionEntity restored = await UpdateStreak(repository)(0);

    expect(restored.streak, 0);
    expect(restored.xp, 900);
    expect(restored.level, 4);
    expect(repository.value, same(restored));
  });

  final Map<String, Future<ProgressionEntity> Function(_Repository)> invalid =
      <String, Future<ProgressionEntity> Function(_Repository)>{
        'negative XP': (_Repository repository) => UpdateXp(repository)(-1),
        'zero level': (_Repository repository) => UpdateLevel(repository)(0),
        'negative streak': (_Repository repository) =>
            UpdateStreak(repository)(-1),
      };
  for (final String name in invalid.keys) {
    test('$name is rejected before accessing stored progression', () async {
      final _Repository repository = _Repository(original);
      await expectLater(invalid[name]!(repository), throwsArgumentError);
      expect(repository.reads, 0);
      expect(repository.writes, 0);
      expect(repository.value, same(original));
    });
  }

  final Map<String, Future<ProgressionEntity> Function(_Repository)> updates =
      <String, Future<ProgressionEntity> Function(_Repository)>{
        'XP': (_Repository repository) => UpdateXp(repository)(400),
        'level': (_Repository repository) => UpdateLevel(repository)(4),
        'streak': (_Repository repository) => UpdateStreak(repository)(0),
      };
  for (final String name in updates.keys) {
    test('$name restore cannot overwrite an unreadable profile', () async {
      final _Repository repository = _Repository(original)..failRead = true;
      await expectLater(updates[name]!(repository), throwsStateError);
      expect(repository.writes, 0);
      expect(repository.value, same(original));
    });
    test('$name restore reports failed persistence', () async {
      final _Repository repository = _Repository(original)..failWrite = true;
      await expectLater(updates[name]!(repository), throwsStateError);
      expect(repository.writes, 1);
      expect(repository.value, same(original));
    });
  }
}
