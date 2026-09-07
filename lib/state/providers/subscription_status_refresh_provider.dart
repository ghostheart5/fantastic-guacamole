import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/state/providers/billing_availability_provider.dart';
import 'package:fantastic_guacamole/state/providers/entitlement_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings and the paywall can live outside NavigationShell. Keep their
/// subscription snapshots current on entry, return from Play, and while open,
/// including when an inactive subscription is resumed outside ChronoSpark.
final subscriptionStatusRefreshProvider = Provider.autoDispose<void>((ref) {
  if (!ref.watch(subscriptionPurchasingEnabledProvider)) return;
  bool disposed = false;
  bool listening = true;
  bool refreshing = false;
  Future<void> refresh() async {
    if (disposed || !listening || refreshing) return;
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    refreshing = true;
    try {
      await ref.read(entitlementAuthorityRefreshProvider)(force: true);
    } catch (_) {
      // Authority failures must not synthesize access or break navigation.
      Logger.warn('Subscription status refresh failed.');
    } finally {
      refreshing = false;
    }
  }

  final observer = _SubscriptionLifecycleObserver(refresh);
  WidgetsBinding.instance.addObserver(observer);
  final interval = ref.watch(entitlementAuthorityRecheckIntervalProvider);
  Timer? timer;
  void startRechecks() {
    timer?.cancel();
    if (interval > Duration.zero) {
      timer = Timer.periodic(interval, (_) => unawaited(refresh()));
    }
    scheduleMicrotask(refresh);
  }

  // Defer provider mutations until the subscribing screen has finished build.
  startRechecks();
  ref.onCancel(() {
    listening = false;
    timer?.cancel();
  });
  ref.onResume(() {
    listening = true;
    startRechecks();
  });
  ref.onDispose(() {
    disposed = true;
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(observer);
  });
});

class _SubscriptionLifecycleObserver extends WidgetsBindingObserver {
  _SubscriptionLifecycleObserver(this.refresh);

  final Future<void> Function() refresh;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }
}
