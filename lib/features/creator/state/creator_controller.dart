import 'package:fantastic_guacamole/features/creator/state/creator_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreatorController extends Notifier<CreatorState> {
  @override
  CreatorState build() => CreatorState.initial();
}
