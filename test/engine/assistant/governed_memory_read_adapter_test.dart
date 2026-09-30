import 'package:fantastic_guacamole/domain/assistant/axiomara_memory_contract.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/engine/assistant/governed_memory_read_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const adapter = GovernedMemoryReadAdapter();
  final now = DateTime.utc(2026, 9, 30);

  MemoryEntity eligibleMemory({required String provenance}) => MemoryEntity(
    id: 'memory-1',
    text: 'Prefers morning planning.',
    date: now.subtract(const Duration(days: 1)),
    accountScopeId: 'account-a',
    sourceSurface: MemorySurface.smartPlanner,
    purpose: MemoryPurpose.guidancePreference,
    sensitivity: MemorySensitivity.standard,
    consentStatus: MemoryConsentStatus.granted,
    consentedAt: now.subtract(const Duration(days: 1)),
    expiresAt: now.add(const Duration(days: 30)),
    provenance: provenance,
    whyStored: 'User opted in.',
  );

  test('unrecognized provenance is not represented as user provided', () {
    final context = adapter.contextFromEligibleMemories(
      accountScopeId: 'account-a',
      memories: <MemoryEntity>[
        eligibleMemory(provenance: 'Opaque legacy import'),
      ],
      requestingSurface: MemorySurface.smartPlanner,
      now: now,
    );

    expect(context.records.single.provenance, AxiomaraMemoryProvenance.unknown);
  });

  test('explicit user provenance remains user provided', () {
    final context = adapter.contextFromEligibleMemories(
      accountScopeId: 'account-a',
      memories: <MemoryEntity>[
        eligibleMemory(provenance: 'User-entered in Smart Planner dialog.'),
      ],
      requestingSurface: MemorySurface.smartPlanner,
      now: now,
    );

    expect(
      context.records.single.provenance,
      AxiomaraMemoryProvenance.userProvided,
    );
  });
}
