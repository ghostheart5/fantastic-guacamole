import 'dart:convert';

import 'package:fantastic_guacamole/core/async/account_storage_mutation.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_history.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';

/// Instances share the account mutation lock with account cleanup. A revision
/// check prevents an older screen or a paid reply from reviving cleared history.
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

  Future<AssistantConversationHistory> _read() async {
    _checkCurrent();
    final raw = await _store.readString(storageKey);
    _checkCurrent();
    if (raw == null) return AssistantConversationHistory();
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
    return AssistantConversationHistory(
      revision: decoded['revision'] as int,
      messages: messages,
      sources: sources,
    );
  }

  Future<AssistantConversationHistory> load() =>
      runAccountStorageMutation(_read);

  Future<int> save({
    required int expectedRevision,
    required List<Map<String, String>> messages,
    required Set<SIV2Source> sources,
  }) => runAccountStorageMutation(() async {
    final previous = await _read();
    if (previous.revision != expectedRevision) {
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
    return _write(previous.revision + 1, safe, sources);
  });

  Future<int> _write(
    int revision,
    List<Map<String, String>> messages,
    Set<SIV2Source> sources,
  ) async {
    _checkCurrent();
    final encoded = jsonEncode({
      'version': 1,
      'revision': revision,
      'messages': messages,
      'sources': sources.map((s) => s.name).toList(),
    });
    if (encoded.length > maxEncodedLength) {
      throw const FormatException('chat_size');
    }
    await _store.writeString(storageKey, encoded);
    _checkCurrent();
    return revision;
  }

  Future<int> clear() => runAccountStorageMutation(() async {
    _checkCurrent();
    var revision = 0;
    try {
      revision = (await _read()).revision;
    } on FormatException {
      // Explicit clearing may replace corrupt data; loading never rewrites it.
    }
    // Keep an empty tombstone so a prior screen's save cannot resurrect data.
    final now = DateTime.now().microsecondsSinceEpoch;
    return _write(now > revision ? now : revision + 1, const [], const {});
  });
}
