import 'dart:async';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const Duration currentEmotionFreshness = Duration(hours: 2);

class EmotionCheckIn {
  const EmotionCheckIn({
    this.value,
    this.reportedAt,
    this.shareWithPlanning = false,
  });

  final EmotionalState? value;
  final DateTime? reportedAt;
  final bool shareWithPlanning;

  bool isFreshAt(DateTime now) {
    final DateTime? observed = reportedAt;
    if (value == null || observed == null) return false;
    final Duration age = now.toUtc().difference(observed.toUtc());
    return !age.isNegative && age <= currentEmotionFreshness;
  }
}

final emotionCheckInProvider =
    NotifierProvider<EmotionNotifier, EmotionCheckIn>(EmotionNotifier.new);

final emotionClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final currentPlannerEmotionProvider = Provider<EmotionalState?>((ref) {
  final checkIn = ref.watch(emotionCheckInProvider);
  return checkIn.isFreshAt(ref.watch(emotionClockProvider)())
      ? checkIn.value
      : null;
});

final emotionProvider = Provider<EmotionalState>((Ref ref) {
  return ref.watch(emotionCheckInProvider).value ?? EmotionalState.neutral;
});

final observedEmotionProvider = Provider<EmotionalState?>((Ref ref) {
  final EmotionCheckIn checkIn = ref.watch(emotionCheckInProvider);
  return checkIn.shareWithPlanning &&
          checkIn.isFreshAt(ref.watch(emotionClockProvider)())
      ? checkIn.value
      : null;
});

class EmotionNotifier extends Notifier<EmotionCheckIn> {
  Timer? _expiry;
  @override
  EmotionCheckIn build() {
    ref.watch(accountStorageScopeProvider);
    ref.watch(
      personalizationProfileProvider.select((p) => p.allowsEmotionSignals),
    );
    _expiry?.cancel();
    ref.onDispose(() => _expiry?.cancel());
    return const EmotionCheckIn();
  }

  void set(EmotionalState value, {DateTime? reportedAt}) {
    if (!ref.read(accountStorageScopeProvider).isWritable) return;
    final now = ref.read(emotionClockProvider)().toUtc();
    final at = (reportedAt ?? now).toUtc();
    _expiry?.cancel();
    state = EmotionCheckIn(
      value: value,
      reportedAt: at,
      shareWithPlanning: state.shareWithPlanning,
    );
    if (!state.isFreshAt(now)) {
      clear();
      return;
    }
    _expiry = Timer(
      at.add(currentEmotionFreshness).difference(now) +
          const Duration(milliseconds: 1),
      clear,
    );
  }

  void share(bool enabled) {
    if (!ref.read(accountStorageScopeProvider).isWritable ||
        !ref.read(personalizationProfileProvider).allowsEmotionSignals) {
      return;
    }
    if (!state.isFreshAt(ref.read(emotionClockProvider)())) {
      clear();
      return;
    }
    state = EmotionCheckIn(
      value: state.value,
      reportedAt: state.reportedAt,
      shareWithPlanning: enabled,
    );
  }

  void clear() {
    _expiry?.cancel();
    state = const EmotionCheckIn();
  }
}
