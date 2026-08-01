import 'dart:convert';

enum SyncOperationType { create, update, delete }

class SyncOperation {
  const SyncOperation({
    required this.operationId,
    required this.tableName,
    required this.recordId,
    required this.operationType,
    required this.payload,
    required this.userId,
    required this.createdAtUtc,
    required this.retryCount,
    required this.nextRetryAtUtc,
    required this.lastError,
  });

  final String operationId;
  final String tableName;
  final String recordId;
  final SyncOperationType operationType;
  final Map<String, dynamic> payload;
  final String userId;
  final DateTime createdAtUtc;
  final int retryCount;
  final DateTime? nextRetryAtUtc;
  final String? lastError;

  SyncOperation copyWith({
    String? operationId,
    String? tableName,
    String? recordId,
    SyncOperationType? operationType,
    Map<String, dynamic>? payload,
    String? userId,
    DateTime? createdAtUtc,
    int? retryCount,
    DateTime? nextRetryAtUtc,
    String? lastError,
  }) {
    return SyncOperation(
      operationId: operationId ?? this.operationId,
      tableName: tableName ?? this.tableName,
      recordId: recordId ?? this.recordId,
      operationType: operationType ?? this.operationType,
      payload: payload ?? this.payload,
      userId: userId ?? this.userId,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAtUtc: nextRetryAtUtc ?? this.nextRetryAtUtc,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'operationId': operationId,
      'tableName': tableName,
      'recordId': recordId,
      'operationType': operationType.name,
      'payload': payload,
      'userId': userId,
      'createdAtUtc': createdAtUtc.toIso8601String(),
      'retryCount': retryCount,
      'nextRetryAtUtc': nextRetryAtUtc?.toIso8601String(),
      'lastError': lastError,
    };
  }

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      operationId: json['operationId']?.toString() ?? '',
      tableName: json['tableName']?.toString() ?? '',
      recordId: json['recordId']?.toString() ?? '',
      operationType: SyncOperationType.values.firstWhere(
        (SyncOperationType value) => value.name == json['operationType'],
        orElse: () => SyncOperationType.update,
      ),
      payload: Map<String, dynamic>.from(
        (json['payload'] as Map?) ?? const <String, dynamic>{},
      ),
      userId: json['userId']?.toString() ?? '',
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      retryCount: (json['retryCount'] as int?) ?? 0,
      nextRetryAtUtc: json['nextRetryAtUtc'] == null
          ? null
          : DateTime.tryParse(json['nextRetryAtUtc'].toString()),
      lastError: json['lastError']?.toString(),
    );
  }

  String encode() => jsonEncode(toJson());

  factory SyncOperation.decode(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid SyncOperation payload.');
    }
    return SyncOperation.fromJson(decoded);
  }
}
