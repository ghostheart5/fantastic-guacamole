import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/plan_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/domain/entities/plan_proposal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDirectory;
  late HiveStorage<String> storage;
  late PlanRepository repository;

  final DateTime now = DateTime.utc(2026, 8, 20, 9);

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'plan_repository_schema_test_',
    );
    await Hive.close();
    Hive.init(tempDirectory.path);
    storage = HiveStorage<String>(
      'plan_repository_schema',
      hive: _DirectHiveStore(),
    );
    await storage.open();
    repository = PlanRepository(storage);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  PlanProposalEntity proposal(String id) => PlanProposalEntity(
    id: id,
    date: now,
    generatedAt: now,
    blocks: <TimeBlock>[
      TimeBlock(
        id: 'block-$id',
        taskId: 'task-$id',
        title: 'Focused work',
        description: 'Typed proposal persistence',
        start: now,
        end: now.add(const Duration(minutes: 30)),
      ),
    ],
    evidenceSources: const <String>['tasks'],
  );

  test(
    'production repository writes and reads schema-versioned proposals',
    () async {
      await repository.saveProposal(proposal('roundtrip'));

      final String stored = storage.get('proposal:roundtrip')!;
      final Map<String, dynamic> json =
          jsonDecode(stored) as Map<String, dynamic>;
      final PlanProposalEntity? loaded = await repository.getProposal(
        'roundtrip',
      );

      expect(json['schemaVersion'], PlanProposalEntity.currentSchemaVersion);
      expect(loaded?.id, 'roundtrip');
      expect(loaded?.blocks.single.description, 'Typed proposal persistence');
    },
  );

  test('production repository upgrades the prior unversioned shape', () async {
    final Map<String, Object?> legacy = proposal('legacy').toJson()
      ..remove('schemaVersion');
    final List<Object?> blocks = legacy['blocks']! as List<Object?>;
    final Map<String, Object?> legacyBlock = Map<String, Object?>.from(
      blocks.single as Map<String, Object?>,
    )..remove('description');
    legacy['blocks'] = <Object?>[legacyBlock];
    await storage.put('proposal:legacy', jsonEncode(legacy));

    final PlanProposalEntity? loaded = await repository.getProposal('legacy');

    expect(loaded?.schemaVersion, PlanProposalEntity.currentSchemaVersion);
    expect(loaded?.blocks.single.description, isNull);
  });

  test('production repository rejects malformed proposal payloads', () async {
    final Map<String, Object?> malformed = proposal('malformed').toJson()
      ..['sourceDecisionId'] = 42;
    await storage.put('proposal:malformed', jsonEncode(malformed));

    expect(() => repository.getProposal('malformed'), throwsFormatException);
  });
}

class _DirectHiveStore implements HiveStore {
  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);

  @override
  Future<Box<T>> openBox<T>(String key) async {
    if (Hive.isBoxOpen(key)) return Hive.box<T>(key);
    return Hive.openBox<T>(key);
  }

  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);

  @override
  Future<void> clearBox(String key) async {
    final Box<String> box = Hive.isBoxOpen(key)
        ? Hive.box<String>(key)
        : await Hive.openBox<String>(key);
    await box.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) await Hive.box<String>(key).close();
  }
}
