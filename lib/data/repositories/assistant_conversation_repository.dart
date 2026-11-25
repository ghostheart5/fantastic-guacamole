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

typedef _PendingView = ({
  Map<ConversationSurface, PendingConversationRequest> pending,
  Set<ConversationSurface> unreadable,
  Map<ConversationSurface, String> expired,
});

/// Instances share the account mutation lock with account cleanup. A revision
/// check prevents an older screen or a paid reply from reviving cleared history.
///
/// A confirmed paid request is stored in the same account-scoped envelope, so
/// account cleanup removes it and it can never reach another account. Writing
/// or clearing it keeps the message revision unchanged, and works on the raw
/// envelope: damaged Chat data never blocks Choose a step and is never
/// rewritten by it. Once a request can no longer be collected its body is
/// replaced by a content-free marker so the person can still be told.
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

  /// The stored JSON object, or null when nothing is stored.
  Future<Map<String, dynamic>?> _readRaw() async {
    _checkCurrent();
    final raw = await _store.readString(storageKey);
    _checkCurrent();
    if (raw == null) return null;
    if (raw.length > maxEncodedLength) throw const FormatException('chat_size');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('chat_envelope');
    }
    return decoded;
  }

  Future<_Envelope> _read() async => _parse(await _readRaw());

  _Envelope _parse(Map<String, dynamic>? decoded) {
    if (decoded == null) {
      return (
        history: AssistantConversationHistory(),
        pending: <String, Object?>{},
      );
    }
    if (decoded['version'] != 1 ||
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
    final chosen = decoded['sourcesChosen'];
    final explained = decoded['scopeExplained'];
    if ((chosen != null && chosen is! bool) ||
        (explained != null && explained is! bool)) {
      throw const FormatException('chat_sources');
    }
    final view = _parsePending(decoded);
    return (
      history: AssistantConversationHistory(
        revision: decoded['revision'] as int,
        messages: messages,
        sources: sources,
        // Chats stored by an older version have no marker. Their selection,
        // even an empty one, is kept as chosen: an empty one may have been
        // an explicit "just this chat" and is never widened silently. An
        // older save or Clear never wrote revision 0, so revision 0 with no
        // messages was written only to hold a Choose a step request: no choice.
        sourcesChosen:
            chosen as bool? ?? !(decoded['revision'] == 0 && messages.isEmpty),
        scopeExplained: explained == true,
        pendingRequests: view.pending,
        unreadablePendingRequests: view.unreadable,
        expiredPendingRequests: view.expired,
      ),
      pending: _rawPending(decoded),
    );
  }

  static Map<String, Object?> _rawPending(Map<String, dynamic>? decoded) {
    final stored = decoded?['pendingRequests'];
    return stored is Map<String, dynamic>
        ? Map<String, Object?>.of(stored)
        : <String, Object?>{};
  }

  // Older envelopes have no pending requests. A damaged entry never hides
  // saved Chat; it is reported so the screen can tell the person.
  static _PendingView _parsePending(Map<String, dynamic>? decoded) {
    final pending = <ConversationSurface, PendingConversationRequest>{};
    final unreadable = <ConversationSurface>{};
    final expired = <ConversationSurface, String>{};
    final stored = decoded?['pendingRequests'];
    if (stored is Map<String, dynamic>) {
      for (final surface in ConversationSurface.values) {
        if (!stored.containsKey(surface.name)) continue;
        final entry = stored[surface.name];
        if (entry is Map && entry['expired'] == true) {
          final id = entry['requestId'];
          if (id is String) {
            expired[surface] = id;
          } else {
            unreadable.add(surface);
          }
          continue;
        }
        try {
          pending[surface] = PendingConversationRequest.fromJson(
            surface,
            entry,
          );
        } on Object {
          unreadable.add(surface);
        }
      }
    } else if (decoded != null && decoded.containsKey('pendingRequests')) {
      unreadable.addAll(ConversationSurface.values);
    }
    return (pending: pending, unreadable: unreadable, expired: expired);
  }

  /// Replaces the body of every request that can no longer be collected, or
  /// cannot be rebuilt, with a content-free marker. Requests still running in
  /// the app ([keep]) are left alone. Never touches the Chat part.
  ///
  /// Returns the earliest collect-by time of a request still collectable, so
  /// a caller can purge again then.
  Future<DateTime?> _purge(
    Map<String, dynamic>? decoded,
    bool Function(String requestId)? keep,
  ) async {
    if (decoded == null) return null;
    final stored = decoded['pendingRequests'];
    if (stored is! Map<String, dynamic>) return null;
    final now = DateTime.now().toUtc();
    final view = _parsePending(decoded);
    final next = Map<String, Object?>.of(stored);
    var changed = false;
    DateTime? nextDeadline;
    for (final entry in view.pending.entries) {
      if (!entry.value.isExpired(now)) {
        final at = entry.value.collectBefore;
        if (nextDeadline == null || at.isBefore(nextDeadline)) {
          nextDeadline = at;
        }
        continue;
      }
      if (keep?.call(entry.value.requestId) == true) continue;
      next[entry.key.name] = {
        'version': 1,
        'expired': true,
        'requestId': entry.value.requestId,
      };
      changed = true;
    }
    for (final surface in view.unreadable) {
      final current = stored[surface.name];
      if (current is Map &&
          current.length == 2 &&
          current['unreadable'] == true) {
        continue;
      }
      next[surface.name] = {'version': 1, 'unreadable': true};
      changed = true;
    }
    if (changed) await _writeRaw({...decoded, 'pendingRequests': next});
    return nextDeadline;
  }

  /// Loads Chat. Pending requests that can no longer be collected are
  /// reported with their content, then reduced to markers in storage.
  Future<AssistantConversationHistory> load({
    bool Function(String requestId)? keep,
  }) => runAccountStorageMutation(() async {
    final decoded = await _readRaw();
    final envelope = _parse(decoded);
    await _purge(decoded, keep);
    return envelope.history;
  });

  /// Pending requests only, readable even when the Chat part is damaged.
  /// Messages and sources in the result are always empty.
  Future<AssistantConversationHistory> loadPending({
    bool Function(String requestId)? keep,
  }) => runAccountStorageMutation(() async {
    final decoded = await _readRaw();
    final view = _parsePending(decoded);
    await _purge(decoded, keep);
    return AssistantConversationHistory(
      pendingRequests: view.pending,
      unreadablePendingRequests: view.unreadable,
      expiredPendingRequests: view.expired,
    );
  });

  /// Runs when the account's storage becomes ready and when a collect-by time
  /// passes while the app runs, so a request body never outlives it just
  /// because no screen was opened. Returns the next collect-by time, if any.
  Future<DateTime?> purgeExpiredPending({
    bool Function(String requestId)? keep,
  }) => runAccountStorageMutation(() async {
    final Map<String, dynamic>? decoded;
    try {
      decoded = await _readRaw();
    } on FormatException {
      return null;
    }
    return _purge(decoded, keep);
  });

  /// [completedRequestId] removes the Chat request whose reply these
  /// messages publish, in the same write. [sourcesChosen] is false when
  /// [sources] is Chat's default rather than the person's own choice.
  Future<int> save({
    required int expectedRevision,
    required List<Map<String, String>> messages,
    required Set<SIV2Source> sources,
    bool sourcesChosen = true,
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
    return _write(
      previous.history.revision + 1,
      safe,
      sources,
      pending,
      sourcesChosen: sourcesChosen,
      scopeExplained: previous.history.scopeExplained,
    );
  });

  /// A new, empty Chat created only to hold something else. Its selection is
  /// marked as not chosen, so Chat's default still applies; without the
  /// marker it would read as an older chat's explicit empty choice.
  static Map<String, dynamic> _emptyEnvelope() => <String, dynamic>{
    'version': 1,
    'revision': 0,
    'messages': <Object?>[],
    'sources': <Object?>[],
    'sourcesChosen': false,
  };

  /// Records that this account was shown why Chat uses the plan by default.
  /// Everything else stored is kept exactly as it is, revision included.
  Future<void> markScopeExplained() => runAccountStorageMutation(() async {
    final decoded = await _readRaw() ?? _emptyEnvelope();
    if (decoded['scopeExplained'] == true) return;
    await _writeRaw({...decoded, 'scopeExplained': true});
  });

  /// Stores a confirmed request before it is sent, replacing any earlier one
  /// for the same surface. Other stored data is kept exactly as it is, even
  /// when the Chat part cannot be read.
  ///
  /// Returns true when this replaced a marker of an earlier request the
  /// person has not been told about yet, so the caller can tell them now.
  Future<bool> savePending(PendingConversationRequest request) =>
      runAccountStorageMutation(() async {
        final decoded = await _readRaw() ?? _emptyEnvelope();
        final view = _parsePending(decoded);
        final replacedUntold =
            view.expired.containsKey(request.surface) ||
            view.unreadable.contains(request.surface);
        await _writeRaw({
          ...decoded,
          'pendingRequests': {
            ..._rawPending(decoded),
            request.surface.name: request.toJson(),
          },
        });
        return replacedUntold;
      });

  /// Removes the surface's stored request or marker when it is [requestId],
  /// or whatever is stored there when [requestId] is null (an unreadable
  /// entry). Other stored data is kept exactly as it is.
  Future<void> clearPending(
    ConversationSurface surface, {
    required String? requestId,
  }) => runAccountStorageMutation(() async {
    final decoded = await _readRaw();
    if (decoded == null) return;
    final pending = _rawPending(decoded);
    if (!_removePending(pending, surface, requestId)) return;
    final next = {...decoded}..remove('pendingRequests');
    if (pending.isNotEmpty) next['pendingRequests'] = pending;
    await _writeRaw(next);
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

  Future<void> _writeRaw(Map<String, dynamic> envelope) async {
    _checkCurrent();
    final encoded = jsonEncode(envelope);
    if (encoded.length > maxEncodedLength) {
      throw const FormatException('chat_size');
    }
    await _store.writeString(storageKey, encoded);
    _checkCurrent();
  }

  Future<int> _write(
    int revision,
    List<Map<String, String>> messages,
    Set<SIV2Source> sources,
    Map<String, Object?> pending, {
    required bool sourcesChosen,
    required bool scopeExplained,
  }) async {
    await _writeRaw({
      'version': 1,
      'revision': revision,
      'messages': messages,
      'sources': sources.map((s) => s.name).toList(),
      'sourcesChosen': sourcesChosen,
      if (scopeExplained) 'scopeExplained': true,
      if (pending.isNotEmpty) 'pendingRequests': pending,
    });
    return revision;
  }

  /// Clears Chat and its stored request. A request still running on another
  /// surface (Choose a step) is kept so its reply is not lost. Chat goes back
  /// to its default information; the explanation of it stays seen.
  Future<int> clear() => runAccountStorageMutation(() async {
    _checkCurrent();
    var revision = 0;
    var pending = <String, Object?>{};
    var scopeExplained = false;
    try {
      final decoded = await _readRaw();
      pending = _rawPending(decoded)..remove(ConversationSurface.si.name);
      scopeExplained = decoded?['scopeExplained'] == true;
      revision = _parse(decoded).history.revision;
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
      sourcesChosen: false,
      scopeExplained: scopeExplained,
    );
  });
}
