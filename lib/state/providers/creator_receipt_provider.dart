import 'dart:convert';

import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
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
  @override
  Future<CreatorCreationReceipt?> build() async {
    final scope = ref.watch(accountStorageScopeProvider);
    final String? account = scope.v2Namespace;
    if (!scope.isWritable || account == null) return null;
    final String storageKey = 'creator_latest_receipt_v1:$account';
    final String? raw = await ref
        .read(secureStoreProvider)
        .readString(storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return CreatorCreationReceipt.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> record(CreatorCreationReceipt receipt) async {
    final scope = ref.read(accountStorageScopeProvider);
    final String? account = scope.v2Namespace;
    if (!scope.isWritable || account == null) {
      throw StateError(
        'Creator receipts require a verified account storage boundary.',
      );
    }
    await ref
        .read(secureStoreProvider)
        .writeString(
          'creator_latest_receipt_v1:$account',
          jsonEncode(receipt.toJson()),
        );
    state = AsyncData<CreatorCreationReceipt?>(receipt);
  }

  Future<void> clear() async {
    final scope = ref.read(accountStorageScopeProvider);
    final String? account = scope.v2Namespace;
    if (scope.isWritable && account != null) {
      await ref
          .read(secureStoreProvider)
          .delete('creator_latest_receipt_v1:$account');
    }
    state = const AsyncData<CreatorCreationReceipt?>(null);
  }
}
