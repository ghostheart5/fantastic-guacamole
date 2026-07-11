import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

base class AppObserver extends ProviderObserver {
  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    Logger.log(
      'Riverpod',
      'ADD -> ${context.provider.name ?? context.provider.runtimeType}',
    );
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    Logger.log(
      'Riverpod',
      'UPDATE -> ${context.provider.name ?? context.provider.runtimeType}',
    );
  }

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    Logger.log(
      'Riverpod',
      'DISPOSE -> ${context.provider.name ?? context.provider.runtimeType}',
    );
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    Logger.errorCategory(
      'Riverpod Errors',
      'Provider failure -> ${context.provider.name ?? context.provider.runtimeType}',
      error,
      stackTrace,
    );
  }
}
