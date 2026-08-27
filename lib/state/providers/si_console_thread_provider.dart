import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/features/si_console/ui/models/si_console_message.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final siConsoleThreadStoreProvider = Provider<SIConsoleThreadStore>((Ref ref) {
  return SIConsoleThreadStore(
    store: ref.watch(sharedPrefsStoreProvider),
    scope: ref.watch(accountStorageScopeProvider),
  );
});

final siConsoleThreadProvider = FutureProvider<List<SIConsoleMessage>>((
  Ref ref,
) {
  return ref.watch(siConsoleThreadStoreProvider).load();
});

class SIConsoleThreadStore {
  const SIConsoleThreadStore({required this.store, required this.scope});

  final SharedPrefsStore store;
  final AccountStorageScope scope;

  String? get _key {
    final String? namespace = scope.v2Namespace;
    if (!scope.isWritable || namespace == null) return null;
    return 'chronospark.si_console.thread.v1.$namespace';
  }

  Future<List<SIConsoleMessage>> load() async {
    final String? key = _key;
    if (key == null) return const <SIConsoleMessage>[];
    await store.init();
    final String? raw = store.load(key);
    if (raw == null || raw.trim().isEmpty) return const <SIConsoleMessage>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return const <SIConsoleMessage>[];
      return decoded
          .whereType<Map<Object?, Object?>>()
          .map((Map<Object?, Object?> item) {
            final Map<String, dynamic> json = Map<String, dynamic>.from(item);
            return SIConsoleMessage.fromJson(json);
          })
          .where((SIConsoleMessage item) => item.text.trim().isNotEmpty)
          .toList(growable: false);
    } on Object {
      await store.save(
        '$key.corrupt.${DateTime.now().toUtc().millisecondsSinceEpoch}',
        raw,
      );
      return const <SIConsoleMessage>[];
    }
  }

  Future<void> save(List<SIConsoleMessage> messages) async {
    final String? key = _key;
    if (key == null) return;
    final List<SIConsoleMessage> bounded = messages.length <= 80
        ? messages
        : messages.sublist(messages.length - 80);
    await store.save(
      key,
      jsonEncode(
        bounded
            .map((SIConsoleMessage item) => item.toJson())
            .toList(growable: false),
      ),
    );
  }
}
