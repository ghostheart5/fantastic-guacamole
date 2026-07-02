import 'package:fantastic_guacamole/features/flowmap/state/flowmap_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FlowmapController extends Notifier<FlowmapState> {
  @override
  FlowmapState build() => FlowmapState.initial();
}
