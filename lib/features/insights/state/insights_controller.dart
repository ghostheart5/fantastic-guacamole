import 'package:fantastic_guacamole/features/insights/state/insights_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InsightsController extends Notifier<InsightsState> {
  @override
  InsightsState build() => InsightsState.initial();
}
