import 'package:fantastic_guacamole/features/nexus/state/nexus_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NexusController extends Notifier<NexusState> {
  @override
  NexusState build() => NexusState.initial();
}
