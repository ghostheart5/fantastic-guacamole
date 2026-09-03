import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';
import 'package:fantastic_guacamole/domain/policies/memory_governance_policy.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('memory summaries, search, and grouping expose governed receipts', () {
    final DateTime now = DateTime.now();
    final List<MemoryEntity> memories = <MemoryEntity>[
      _memory(
        id: 'recent-starred',
        text: 'Prefer one clear next action',
        date: now.subtract(const Duration(hours: 2)),
        category: MemoryCategory.planningGuidancePreference,
        tags: const <String>['planning', 'clarity'],
        starred: true,
        metadata: const <String, String>{'sourceDetail': 'First-use choice'},
      ),
      _memory(
        id: 'older',
        text: 'Protect morning focus time',
        date: now.subtract(const Duration(days: 5)),
        category: MemoryCategory.userPreference,
        tags: const <String>['planning', 'morning'],
      ),
      _memory(
        id: 'archived',
        text: 'Retired preference',
        date: now.subtract(const Duration(days: 1)),
        category: MemoryCategory.userPreference,
        tags: const <String>['archive'],
        archivedAt: now,
      ),
    ];
    final ProviderContainer container = ProviderContainer(
      overrides: [
        memoriesProvider.overrideWith(() => _StaticMemories(memories)),
      ],
    );
    addTearDown(container.dispose);

    final MemorySummary summary = container.read(memorySummaryProvider);
    expect(summary.total, 3);
    expect(summary.recent, 2);
    expect(summary.starred, 1);
    expect(summary.archived, 1);
    expect(summary.categoryCounts[MemoryCategory.userPreference], 2);
    expect(summary.topTags.first, 'planning');

    expect(
      container
          .read(memorySearchProvider('  '))
          .map((MemoryEntity item) => item.id),
      orderedEquals(<String>['recent-starred', 'older']),
    );
    expect(
      container.read(memorySearchProvider('clear')).single.id,
      'recent-starred',
    );
    expect(
      container.read(memorySearchProvider('first-use')).single.id,
      'recent-starred',
    );
    expect(container.read(memorySearchProvider('retired')), isEmpty);
    expect(container.read(memorySearchProvider('absent')), isEmpty);

    final grouped = container.read(memoriesByCategoryProvider);
    expect(grouped.keys, containsAll(MemoryCategory.values));
    expect(
      grouped[MemoryCategory.planningGuidancePreference]?.single.id,
      'recent-starred',
    );
    expect(grouped[MemoryCategory.userPreference], hasLength(2));

    final Map<String, dynamic> export = container
        .read(memoryGovernanceControllerProvider)
        .exportReceipts();
    expect(export['schemaVersion'], 1);
    expect(export['exportType'], 'chronospark_memory_receipts');
    expect(export['memoryReceipts'], hasLength(3));
  });

  test('empty memory state produces a complete zero summary', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        memoriesProvider.overrideWith(
          () => _StaticMemories(const <MemoryEntity>[]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final MemorySummary summary = container.read(memorySummaryProvider);
    expect(summary.total, 0);
    expect(summary.recent, 0);
    expect(summary.starred, 0);
    expect(summary.archived, 0);
    expect(summary.topTags, isEmpty);
    expect(
      summary.categoryCounts.values.every((int count) => count == 0),
      isTrue,
    );
  });

  test(
    'governed memory lifecycle persists receipts and user controls',
    () async {
      final _FakeMemoryRepository repository = _FakeMemoryRepository();
      final ProviderContainer container = _governedContainer(repository);
      addTearDown(container.dispose);

      final MemoryGovernanceController controller = container.read(
        memoryGovernanceControllerProvider,
      );
      final MemoryReceipt receipt = await controller.rememberPreference(
        text: '  Prefer one concrete next action.  ',
        sourceSurface: MemorySurface.smartPlanner,
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
        consentConfirmed: true,
        whyStored: '  Improve future planning.  ',
        provenance: '  User confirmation.  ',
      );
      expect(receipt.storedText, 'Prefer one concrete next action.');
      expect(receipt.whyStored, 'Improve future planning.');
      expect(receipt.provenance, 'User confirmation.');
      expect(repository.memories.single.accountScopeId, startsWith('v2.'));

      final MemoryReceipt corrected = await controller.correctPreference(
        id: receipt.memoryId,
        text: 'Prefer two concrete next actions.',
      );
      expect(corrected.storedText, 'Prefer two concrete next actions.');

      await container
          .read(memoriesProvider.notifier)
          .toggleStar(receipt.memoryId);
      expect(container.read(memoriesProvider).single.starred, isTrue);
      await container.read(memoriesProvider.notifier).archive(receipt.memoryId);
      expect(container.read(memoriesProvider).single.isArchived, isTrue);

      await container.read(memoriesProvider.notifier).toggleStar('missing');
      await container.read(memoriesProvider.notifier).archive('missing');
      await expectLater(
        controller.correctPreference(id: 'missing', text: 'Still missing.'),
        throwsA(
          isA<MemoryGovernanceException>().having(
            (MemoryGovernanceException error) => error.code,
            'code',
            'memory_not_found',
          ),
        ),
      );

      await controller.deleteMemory(receipt.memoryId);
      expect(container.read(memoriesProvider), isEmpty);
      await controller.rememberPreference(
        text: 'Prefer protected focus time.',
        sourceSurface: MemorySurface.creator,
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 14)),
        consentConfirmed: true,
        whyStored: 'Guide task creation.',
        provenance: 'User confirmation.',
      );
      expect(container.read(memoriesProvider), hasLength(1));
      await controller.deleteAll();
      expect(container.read(memoriesProvider), isEmpty);
      expect(repository.deleteAllCalls, 1);
    },
  );

  test(
    'governed memory rejects missing consent, unsafe surfaces, and receipts',
    () async {
      final ProviderContainer container = _governedContainer(
        _FakeMemoryRepository(),
      );
      addTearDown(container.dispose);
      final MemoriesNotifier notifier = container.read(
        memoriesProvider.notifier,
      );
      final DateTime expiresAt = DateTime.now().toUtc().add(
        const Duration(days: 30),
      );

      Future<void> remember({
        bool consentConfirmed = true,
        MemorySurface surface = MemorySurface.smartPlanner,
        String whyStored = 'Improve planning.',
        String provenance = 'User confirmation.',
      }) => notifier.rememberPreference(
        text: 'Prefer a clear next action.',
        sourceSurface: surface,
        expiresAt: expiresAt,
        consentConfirmed: consentConfirmed,
        whyStored: whyStored,
        provenance: provenance,
      );

      await expectLater(
        remember(consentConfirmed: false),
        _memoryError('consent_required'),
      );
      await expectLater(
        remember(surface: MemorySurface.siConsole),
        _memoryError('surface_not_allowed'),
      );
      await expectLater(
        remember(surface: MemorySurface.unknown),
        _memoryError('surface_not_allowed'),
      );
      await expectLater(
        remember(whyStored: '  '),
        _memoryError('receipt_required'),
      );
      await expectLater(
        remember(provenance: '  '),
        _memoryError('receipt_required'),
      );

      final ProviderContainer signedOut = _governedContainer(
        _FakeMemoryRepository(),
        scope: const AccountStorageScope.signedOut(),
      );
      addTearDown(signedOut.dispose);
      await expectLater(
        signedOut
            .read(memoriesProvider.notifier)
            .rememberPreference(
              text: 'Prefer a clear next action.',
              sourceSurface: MemorySurface.smartPlanner,
              expiresAt: expiresAt,
              consentConfirmed: true,
              whyStored: 'Improve planning.',
              provenance: 'User confirmation.',
            ),
        _memoryError('account_scope_required'),
      );
    },
  );
}

ProviderContainer _governedContainer(
  _FakeMemoryRepository repository, {
  AccountStorageScope? scope,
}) {
  const ConsentedHumanContext consented = ConsentedHumanContext(
    emotionAllowed: false,
    memoryAllowed: true,
    emotion: null,
    siState: SIState(),
  );
  const AssistantReleaseDecision enabledDecision = AssistantReleaseDecision(
    enabled: true,
    shadowEvaluationEnabled: false,
    cohort: AssistantReleaseCohort.general,
    reasonCode: 'cohort_enabled',
    accountDigest: 'test-account-digest',
    capability: AssistantReleaseCapability.governedMemory,
    configDigest: 'test-config-digest',
  );
  return ProviderContainer(
    overrides: [
      accountStorageScopeProvider.overrideWithValue(
        scope ?? AccountStorageScope.authenticated('memory-test-account'),
      ),
      consentedHumanContextProvider.overrideWithValue(consented),
      domainMemoryRepositoryProvider.overrideWithValue(repository),
      assistantReleaseDecisionProvider(
        AssistantReleaseCapability.governedMemory,
      ).overrideWith((Ref ref) async => enabledDecision),
    ],
  );
}

Matcher _memoryError(String code) => throwsA(
  isA<MemoryGovernanceException>().having(
    (MemoryGovernanceException error) => error.code,
    'code',
    code,
  ),
);

MemoryEntity _memory({
  required String id,
  required String text,
  required DateTime date,
  required MemoryCategory category,
  required List<String> tags,
  bool starred = false,
  DateTime? archivedAt,
  Map<String, String> metadata = const <String, String>{},
}) {
  return MemoryEntity(
    id: id,
    text: text,
    date: date,
    category: category,
    tags: tags,
    starred: starred,
    archivedAt: archivedAt,
    metadata: metadata,
    accountScopeId: 'account-v2',
    sourceSurface: MemorySurface.smartPlanner,
    purpose: MemoryPurpose.guidancePreference,
    sensitivity: MemorySensitivity.standard,
    consentStatus: MemoryConsentStatus.granted,
    consentedAt: date,
    expiresAt: date.add(const Duration(days: 30)),
    provenance: 'User confirmed',
    whyStored: 'Improve planning guidance',
  );
}

final class _StaticMemories extends MemoriesNotifier {
  _StaticMemories(this._value);

  final List<MemoryEntity> _value;

  @override
  List<MemoryEntity> build() => _value;
}

final class _FakeMemoryRepository implements IMemoryRepository {
  final List<MemoryEntity> memories = <MemoryEntity>[];
  int deleteAllCalls = 0;

  @override
  Future<void> deleteAllMemories() async {
    deleteAllCalls += 1;
    memories.clear();
  }

  @override
  Future<void> deleteMemory(String id) async {
    memories.removeWhere((MemoryEntity memory) => memory.id == id);
  }

  @override
  List<MemoryEntity> getMemories() => List<MemoryEntity>.unmodifiable(memories);

  @override
  List<MemoryEntity> getMemoriesForSurface(MemorySurface surface) => memories
      .where((MemoryEntity memory) => memory.sourceSurface == surface)
      .toList(growable: false);

  @override
  Future<void> saveMemories(List<MemoryEntity> memories) async {
    this.memories
      ..clear()
      ..addAll(memories);
  }

  @override
  Future<void> saveMemory(MemoryEntity memory) async {
    final int index = memories.indexWhere(
      (MemoryEntity item) => item.id == memory.id,
    );
    if (index < 0) {
      memories.add(memory);
    } else {
      memories[index] = memory;
    }
  }
}
