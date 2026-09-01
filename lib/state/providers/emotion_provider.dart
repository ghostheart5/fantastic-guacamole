import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const Duration currentEmotionFreshness = Duration(hours: 2);

class EmotionCheckIn {
  const EmotionCheckIn({this.value, this.reportedAt});

  final EmotionalState? value;
  final DateTime? reportedAt;

  bool isFreshAt(DateTime now) {
    final DateTime? observed = reportedAt;
    if (value == null || observed == null) return false;
    final Duration age = now.toUtc().difference(observed.toUtc());
    return !age.isNegative && age <= currentEmotionFreshness;
  }
}

final emotionCheckInProvider =
    NotifierProvider<EmotionNotifier, EmotionCheckIn>(EmotionNotifier.new);

final emotionProvider = Provider<EmotionalState>((Ref ref) {
  return ref.watch(emotionCheckInProvider).value ?? EmotionalState.neutral;
});

final observedEmotionProvider = Provider<EmotionalState?>((Ref ref) {
  final EmotionCheckIn checkIn = ref.watch(emotionCheckInProvider);
  return checkIn.isFreshAt(DateTime.now()) ? checkIn.value : null;
});

class EmotionNotifier extends Notifier<EmotionCheckIn> {
  @override
  EmotionCheckIn build() => const EmotionCheckIn();

  void set(EmotionalState value, {DateTime? reportedAt}) {
    state = EmotionCheckIn(
      value: value,
      reportedAt: (reportedAt ?? DateTime.now()).toUtc(),
    );
  }

  void clear() => state = const EmotionCheckIn();
}
