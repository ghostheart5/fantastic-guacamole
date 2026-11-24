import 'dart:convert';

import 'package:fantastic_guacamole/core/async/account_storage_mutation.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_history.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';

typedef _Envelope = ({
  AssistantConversationHistory history,
  Map<String, Object?> pending,
});

/// Instances share the account mutation lock with account cleanup. A revision
/// check prevents an older screen or a paid reply from reviving cleared history.
///
/// A confirmed paid request is stored in the same account-scoped envelope, so
/// account cleanup removes it and it can never reach another account. Writing
/// or clearing it keeps the message revision unchanged.
class AssistantConversationRepository {
  AssistantConversationRepository(this._store, {required this._isCurrent});

  static const storageKey = 'assistant_chat_history_v1';
  static const maxMessages = AssistantConversationHistory.maxMessages;
  static const maxMessageLength = 6000;
  static const maxEncodedLength = 1500000;
  final SecureStore _store;
  final bool Function() _isCurrent;

  void _checkCurrent() {
    if (!_isCurrent()) throw StateError('chat_account_changed');
  }

  Future<_Envelope> _read() async {
    _checkCurrent();
    final raw = await _store.readString(storageKey);
    _checkCurrent();
    if (raw == null) {
      return (
        history: AssistantConversationHistory(),
        pending: <String, Object?>{},
      );
    }
    if (raw.length > maxEncodedLength) throw const FormatException('chat_size');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != 1 ||
        decoded['revision'] is! int ||
        (decoded['revision'] as int) < 0 ||
        decoded['messages'] is! List ||
        decoded['sources'] is! List) {
      throw const FormatException('chat_envelope');
    }
    final turns = decoded['messages'] as List;
    if (turns.length > maxMessages || turns.length.isOdd) {
      throw const FormatException('chat_pairs');
    }
    final messages = <Map<String, String>>[];
    for (var i = 0; i < turns.length; i++) {
      final turn = turns[i];
      if (turn is! Map ||
          turn.length != 2 ||
          turn['role'] != (i.isEven ? 'user' : 'assistant') ||
          turn['content'] is! String ||
          (turn['content'] as String).isEmpty ||
          (turn['content'] as String).length > maxMessageLength) {
        throw const FormatException('chat_turn');
      }
      messages.add({
        'role': turn['role'] as String,
        'content': turn['content'] as String,
      });
    }
    final sources = <SIV2Source>{};
    for (final value in decoded['sources'] as List) {
      final matches = SIV2Source.values.where((source) => source.name == value);
      if (matches.length != 1 || !sources.add(matches.single)) {
        throw const FormatException('chat_sources');
      }
    }
    // Older envelopes have no pending requests. A damaged pending entry never
    // hides saved Chat; it is reported so the screen can tell the person.
    final storedPending = decoded['pendingRequests'];
    final rawPending = <String, Object?>{};
    final pending = <ConversationSurface, PendingConversationRequest>{};
    final unreadable = <ConversationSurface>{};
    if (storedPending is Map<String, dynamic>) {
      rawPending.addAll(storedPending);
      for (final surface in ConversationSurface.values) {
        if (!storedPending.containsKey(surface.name)) continue;
        try {
          pending[surface] = PendingConversationRequest.fromJson(
            surface,
            storedPending[surface.name],
          );
        } on Object {
          unreadable.add(surface);
        }
      }
    } else if (decoded.containsKey('pendingRequests')) {
      unreadable.addAll(ConversationSurface.values);
    }
    return (
      history: AssistantConversationHistory(
        revision: decoded['revision'] as int,
        messages: messages,
        sources: sources,
        pendingRequests: pending,
        unreadablePendingRequests: unreadable,
      ),
      pending: rawPending,
    );
  }

  Future<AssistantConversationHistory> load() =>
      runAccountStorageMutation(() async => (await _read()).history);

  /// [completedRequestId] removes the Chat request whose reply these
  /// messages publish, in the same write.
  Future<int> save({
    required int expectedRevision,
    required List<Map<String, String>> messages,
    required Set<SIV2Source> sources,
    String? completedRequestId,
  }) => runAccountStorageMutation(() async {
    final previous = await _read();
    if (previous.history.revision != expectedRevision) {
      throw AssistantConversationRevisionConflict();
    }
    if (messages.length.isOdd) throw const FormatException('chat_pairs');
    final retained = messages
        .skip(messages.length > maxMessages ? messages.length - maxMessages : 0)
        .toList();
    final safe = <Map<String, String>>[];
    for (var i = 0; i < retained.length; i++) {
      final turn = retained[i];
      final content = turn['content'];
      if (turn['role'] != (i.isEven ? 'user' : 'assistant') ||
          content == null ||
          content.isEmpty) {
        throw const FormatException('chat_turn');
      }
      safe.add({
        'role': turn['role']!,
        'content': content.length > maxMessageLength
            ? content.substring(0, maxMessageLength)
            : content,
      });
    }
    final pending = Map<String, Object?>.of(previous.pending);
    if (completedRequestId != null) {
      _removePending(pending, ConversationSurface.si, completedRequestId);
    }
    return _write(previous.history.revision + 1, safe, sources, pending);
  });

  /// Stores a confirmed request before it is sent, replacing any earlier one
  /// for the same surface.
  Future<void> savePending(PendingConversationRequest request) =>
      runAccountStorageMutation(() async {
        final previous = await _read();
        await _write(
          previous.history.revision,
          previous.history.messages,
          previous.history.sources,
          {...previous.pending, request.surface.name: request.toJson()},
        );
      });

  /// Removes the surface's stored request when it is [requestId], or whatever
  /// is stored there when [requestId] is null (an unreadable entry).
  Future<void> clearPending(
    ConversationSurface surface, {
    required String? requestId,
  }) => runAccountStorageMutation(() async {
    final previous = await _read();
    final pending = Map<String, Object?>.of(previous.pending);
    if (!_removePending(pending, surface, requestId)) return;
    await _write(
      previous.history.revision,
      previous.history.messages,
      previous.history.sources,
      pending,
    );
  });

  static bool _removePending(
    Map<String, Object?> pending,
    ConversationSurface surface,
    String? requestId,
  ) {
    final entry = pending[surface.name];
    if (!pending.containsKey(surface.name) ||
        (requestId != null &&
            (entry is! Map || entry['requestId'] != requestId))) {
      return false;
    }
    pending.remove(surface.name);
    return true;
  }

  Future<int> _write(
    int revision,
    List<Map<String, String>> messages,
    Set<SIV2Source> sources,
    Map<String, Object?> pending,
  ) async {
    _checkCurrent();
    final encoded = jsonEncode({
      'version': 1,
      'revision': revision,
      'messages': messages,
      'sources': sources.map((s) => s.name).toList(),
      if (pending.isNotEmpty) 'pendingRequests': pending,
    });
    if (encoded.length > maxEncodedLength) {
      throw const FormatException('chat_size');
    }
    await _store.writeString(storageKey, encoded);
    _checkCurrent();
    return revision;
  }

  /// Clears Chat and its stored request. A request still running on another
  /// surface (Choose a step) is kept so its reply is not lost.
  Future<int> clear() => runAccountStorageMutation(() async {
    _checkCurrent();
    var revision = 0;
    var pending = <String, Object?>{};
    try {
      final previous = await _read();
      revision = previous.history.revision;
      pending = Map<String, Object?>.of(previous.pending)
        ..remove(ConversationSurface.si.name);
    } on FormatException {
      // Explicit clearing may replace corrupt data; loading never rewrites it.
    }
    // Keep an empty tombstone so a prior screen's save cannot resurrect data.
    final now = DateTime.now().microsecondsSinceEpoch;
    return _write(
      now > revision ? now : revision + 1,
      const [],
      const {},
      pending,
    );
  });
}
