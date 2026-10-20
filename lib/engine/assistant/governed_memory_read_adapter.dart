import 'package:fantastic_guacamole/domain/assistant/axiomara_memory_contract.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';

/// Read-only bridge from Axiomara's governed durable memory into the unified
/// assistant memory contract. This adapter never weakens MemoryEntity's
/// consent, expiry, sensitivity, account-scope, or surface restrictions.
final class GovernedMemoryReadAdapter {
  const GovernedMemoryReadAdapter();

  AxiomaraMemoryContext contextFromEligibleMemories({
    required String accountScopeId,
    required Iterable<MemoryEntity> memories,
    required MemorySurface requestingSurface,
    required DateTime now,
    int limit = 12,
  }) {
    if (accountScopeId.trim().isEmpty || limit < 0) {
      throw const AxiomaraMemoryContractException(
        'Governed memory recall requires a valid account scope and limit.',
      );
    }

    final List<AxiomaraMemoryRecord> records = memories
        .where(
          (MemoryEntity memory) => memory.canBeRetrieved(
            requestingAccountScopeId: accountScopeId,
            requestingSurface: requestingSurface,
            now: now,
          ),
        )
        .take(limit)
        .map(
          (MemoryEntity memory) => AxiomaraMemoryRecord(
            id: memory.id,
            accountScopeId: memory.accountScopeId,
            kind: _kind(memory),
            provenance: _provenance(memory),
            text: memory.text,
            recordedAt: memory.date,
            sourceId: memory.source,
            confidence: memory.importance,
          ),
        )
        .toList(growable: false);

    final AxiomaraMemoryContext context = AxiomaraMemoryContext(
      accountScopeId: accountScopeId,
      records: records,
    );
    context.validate();
    return context;
  }

  AxiomaraMemoryKind _kind(MemoryEntity memory) => switch (memory.purpose) {
    MemoryPurpose.guidancePreference => AxiomaraMemoryKind.preference,
    MemoryPurpose.outcomeLearning => AxiomaraMemoryKind.outcome,
    MemoryPurpose.userNote => AxiomaraMemoryKind.userFact,
    MemoryPurpose.unknown => switch (memory.category) {
      MemoryCategory.goal ||
      MemoryCategory.task ||
      MemoryCategory.lifeArea => AxiomaraMemoryKind.project,
      MemoryCategory.habit ||
      MemoryCategory.signal => AxiomaraMemoryKind.pattern,
      MemoryCategory.importantDate ||
      MemoryCategory.achievement => AxiomaraMemoryKind.event,
      _ => AxiomaraMemoryKind.userFact,
    },
  };

  AxiomaraMemoryProvenance _provenance(MemoryEntity memory) {
    final String value = memory.provenance.trim().toLowerCase();
    return switch (value) {
      'user-entered in smart planner memory consent dialog.' ||
      'user-entered in smart planner dialog.' ||
      'user-entered preference dialog.' ||
      'user confirmation.' ||
      'user confirmed' => AxiomaraMemoryProvenance.userProvided,
      'observed' => AxiomaraMemoryProvenance.observed,
      'inferred' => AxiomaraMemoryProvenance.inferred,
      'system-generated' => AxiomaraMemoryProvenance.systemGenerated,
      _ => AxiomaraMemoryProvenance.unknown,
    };
  }
}
