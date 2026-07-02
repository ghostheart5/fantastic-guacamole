import 'package:fantastic_guacamole/features/plan/state/plan_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlanController extends Notifier<PlanState> {
  @override
  PlanState build() => PlanState.initial();
}
