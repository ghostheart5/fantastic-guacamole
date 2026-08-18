import 'dart:convert';

import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/state/models/creator_creation_receipt.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final latestCreatorReceiptProvider =
    AsyncNotifierProvider<
      LatestCreatorReceiptNotifier,
      CreatorCreationReceipt?
    >(LatestCreatorReceiptNotifier.new);

class LatestCreatorReceiptNotifier
    extends AsyncNotifier<CreatorCreationReceipt?> {
  String _storageKey = 'creator_latest_receipt_v1:local';

  @override
  Future<CreatorCreationReceipt?> build() async {
    final String account =
        ref.watch(accountStorageScopeProvider).v2Namespace ?? 'local';
    _storageKey = 'creator_latest_receipt_v1:$account';
    final String? raw = await ref
        .read(secureStoreProvider)
        .readString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return CreatorCreationReceipt.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> record(CreatorCreationReceipt receipt) async {
    await ref
        .read(secureStoreProvider)
        .writeString(_storageKey, jsonEncode(receipt.toJson()));
    state = AsyncData<CreatorCreationReceipt?>(receipt);
  }

  Future<void> clear() async {
    await ref.read(secureStoreProvider).delete(_storageKey);
    state = const AsyncData<CreatorCreationReceipt?>(null);
  }
}
