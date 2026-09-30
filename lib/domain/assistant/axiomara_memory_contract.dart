/// CHRONOSPARK-CLASS: SHIPPING | Feature: Axiomara assistant orchestration
enum AxiomaraMemoryKind {
  working,
  preference,
  project,
  event,
  pattern,
  outcome,
  userFact,
}

enum AxiomaraMemoryProvenance {
  unknown,
  userProvided,
  observed,
  inferred,
  systemGenerated,
}

final class AxiomaraMemoryRecord {
  const AxiomaraMemoryRecord({
    required this.id,
    required this.accountScopeId,
    required this.kind,
    required this.provenance,
    required this.text,
    required this.recordedAt,
    this.sourceId,
    this.confidence,
  });

  final String id;
  final String accountScopeId;
  final AxiomaraMemoryKind kind;
  final AxiomaraMemoryProvenance provenance;
  final String text;
  final DateTime recordedAt;
  final String? sourceId;
  final double? confidence;

  void validateForAccount(String expectedAccountScopeId) {
    if (id.trim().isEmpty ||
        text.trim().isEmpty ||
        accountScopeId.trim().isEmpty ||
        accountScopeId != expectedAccountScopeId) {
      throw const AxiomaraMemoryContractException(
        'Memory record failed account or content validation.',
      );
    }
    final double? value = confidence;
    if (value != null && (value < 0 || value > 1)) {
      throw const AxiomaraMemoryContractException(
        'Memory confidence must be between 0 and 1.',
      );
    }
  }
}

final class AxiomaraMemoryContext {
  const AxiomaraMemoryContext({
    required this.accountScopeId,
    required this.records,
  });

  final String accountScopeId;
  final List<AxiomaraMemoryRecord> records;

  void validate() {
    if (accountScopeId.trim().isEmpty) {
      throw const AxiomaraMemoryContractException(
        'Memory context requires an account scope.',
      );
    }
    for (final AxiomaraMemoryRecord record in records) {
      record.validateForAccount(accountScopeId);
    }
  }
}

abstract interface class AxiomaraMemoryPort {
  Future<List<AxiomaraMemoryRecord>> recall({
    required String accountScopeId,
    required String query,
    int limit = 12,
  });

  Future<AxiomaraMemoryContext> contextFor({
    required String accountScopeId,
    required String query,
    int limit = 12,
  });

  Future<void> remember(AxiomaraMemoryRecord record);
  Future<void> correct(AxiomaraMemoryRecord record);
  Future<void> forget({
    required String accountScopeId,
    required String memoryId,
  });
  Future<List<AxiomaraMemoryRecord>> export({required String accountScopeId});
  Future<void> clear({required String accountScopeId});
}

final class AxiomaraMemoryContractException implements Exception {
  const AxiomaraMemoryContractException(this.message);
  final String message;
  @override
  String toString() => 'AxiomaraMemoryContractException: $message';
}
