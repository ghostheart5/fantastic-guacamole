import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';

/// Authenticated, account-scoped authority for durable neural history.
///
/// The ambiguous pre-V2 [legacyStorageKey] is deliberately never read, claimed,
/// copied, or deleted by this store.
class NeuralHistoryStore {
  NeuralHistoryStore({required this.scope, required this._secureStore});

  static const String legacyStorageKey = 'neural_dump';
  static const String _storagePrefix = 'neural_dump_v2.';

  final AccountStorageScope scope;
  final SecureStore _secureStore;

  bool get isAvailable => scope.isAuthenticated;

  String? get storageKey =>
      isAvailable ? '$_storagePrefix${scope.v2Namespace}' : null;

  Future<List<NeuralEntry>> loadNeuralHistory() async {
    final String? key = storageKey;
    if (key == null) return const <NeuralEntry>[];
    final String? raw = await _secureStore.readString(key);
    if (raw == null || raw.trim().isEmpty) return const <NeuralEntry>[];
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return const <NeuralEntry>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(NeuralEntry.fromJson)
          .toList(growable: false);
    } on Object {
      return const <NeuralEntry>[];
    }
  }

  Future<void> appendNeuralEntry(NeuralEntry entry, {int? maxEntries}) async {
    final String? key = storageKey;
    if (key == null) return;
    final List<NeuralEntry> history = await loadNeuralHistory();
    await _secureStore.writeString(
      key,
      jsonEncode(_boundedJson(history, entry, maxEntries)),
    );
  }

  Future<void> replaceNeuralHistory(List<NeuralEntry> history) async {
    final String? key = storageKey;
    if (key == null) return;
    await _secureStore.writeString(
      key,
      jsonEncode(history.map((item) => item.toJson()).toList(growable: false)),
    );
  }
}

List<Map<String, dynamic>> _boundedJson(
  List<NeuralEntry> history,
  NeuralEntry entry,
  int? maxEntries,
) {
  final values = <Map<String, dynamic>>[
    ...history.map((item) => item.toJson()),
    entry.toJson(),
  ];
  if (maxEntries == null || values.length <= maxEntries) return values;
  return values.sublist(values.length - maxEntries);
}
