import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_evidence_plane.dart';

class SiEngineRepository {
  SiEngineRepository(this._store, this._scope);

  static const String _stateKeyPrefix = 'si_engine_state_v2';
  static const String _legacyStateKey = 'si_engine_state_v1';

  final SecureStore _store;
  final AccountStorageScope _scope;

  String? stateKey(AssistantConversationScope conversation) {
    final String? accountNamespace = _scope.v2Namespace;
    final String conversationId = conversation.conversationId.trim();
    if (!_scope.isWritable ||
        accountNamespace == null ||
        conversationId.isEmpty) {
      return null;
    }
    final String encodedConversation = base64UrlEncode(
      utf8.encode(conversationId),
    );
    return '$_stateKeyPrefix.$accountNamespace.${conversation.surface.storageId}.$encodedConversation';
  }

  Future<Map<String, dynamic>?> loadState(
    AssistantConversationScope conversation,
  ) async {
    final String? key = stateKey(conversation);
    if (key == null) return null;
    final String? raw = await _store.readString(key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map<dynamic, dynamic>) {
        return decoded.cast<String, dynamic>();
      }
      return null;
    } on FormatException catch (error) {
      Logger.error('Stored SI engine state is corrupt.', error);
      return null;
    }
  }

  Future<void> saveState(
    AssistantConversationScope conversation,
    Map<String, dynamic> state,
  ) async {
    final String? key = stateKey(conversation);
    if (key == null) return;
    await _store.writeString(key, jsonEncode(state));
  }

  Future<Map<String, dynamic>?> exportState(
    AssistantConversationScope conversation,
  ) async {
    final Map<String, dynamic>? state = await loadState(conversation);
    return state == null ? null : Map<String, dynamic>.from(state);
  }

  Future<void> clearState(AssistantConversationScope conversation) async {
    final String? key = stateKey(conversation);
    if (key == null) return;
    await _store.delete(key);
  }

  /// Legacy state has no provable account or surface owner, so it is never
  /// migrated. It may only be removed by an explicit device-wide memory clear.
  Future<void> clearLegacyState() => _store.delete(_legacyStateKey);
}

extension SiEngineEvidencePlaneRepository on SiEngineRepository {
  String? get accountScopeId => _scope.v2Namespace;

  Future<AssistantEvidenceExchange?> loadAssistantEvidenceExchange(
    AssistantConversationScope conversation,
  ) async {
    final Map<String, dynamic>? state = await loadState(conversation);
    final Object? rawExchange = state?['assistantEvidenceExchange'];
    if (rawExchange is! Map<Object?, Object?>) return null;
    try {
      final AssistantEvidenceExchange exchange =
          AssistantEvidenceExchange.fromJson(
            Map<String, Object?>.from(rawExchange),
          );
      if (exchange.request.accountScopeId != accountScopeId ||
          exchange.request.conversation != conversation) {
        throw const EvidencePlaneException(
          'Persisted evidence exchange does not belong to this repository scope.',
        );
      }
      return exchange;
    } on FormatException catch (error) {
      Logger.error('Stored assistant evidence exchange is invalid.', error);
      return null;
    }
  }
}
