import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared, test-only account labels and safe waiting utilities for feature
/// context certification. Feature tests supply their own real provider graph
/// and use these stable sentinels rather than duplicating account naming.
abstract final class FeatureContextAccountFixture {
  static const String accountA = 'A';
  static const String accountB = 'B';
  static const String accountC = 'C';

  static String sentinel(String account, String field) => '${account}_$field';

  static List<String> foreignSentinels(String current) => <String>[
    for (final String account in <String>[accountA, accountB, accountC])
      if (account != current) account,
  ];
}

/// Retains a real Riverpod async provider until it emits data or an error.
/// This avoids using a transient `.future` across account-scope rebuilds.
Future<T> listenUntilData<T>(
  ProviderContainer container,
  FutureProvider<T> provider, {
  Duration timeout = const Duration(seconds: 3),
  bool Function(T value)? accept,
}) async {
  final Completer<T> result = Completer<T>();
  late ProviderSubscription<AsyncValue<T>> subscription;
  subscription = container.listen(
    provider,
    (_, AsyncValue<T> next) {
      if (next.hasError && !result.isCompleted) {
        result.completeError(next.error!, next.stackTrace);
      }
      if (next.hasValue &&
          (accept == null || accept(next.requireValue)) &&
          !result.isCompleted) {
        result.complete(next.requireValue);
      }
    },
    fireImmediately: true,
  );
  try {
    return await result.future.timeout(timeout);
  } finally {
    subscription.close();
  }
}

void expectNoForeignAccountContext(
  Iterable<String> exposedValues, {
  required String currentAccount,
}) {
  for (final String foreign in FeatureContextAccountFixture.foreignSentinels(
    currentAccount,
  )) {
    if (exposedValues.any((String value) => value.contains('${foreign}_'))) {
      throw StateError('Found $foreign context under $currentAccount.');
    }
  }
}
