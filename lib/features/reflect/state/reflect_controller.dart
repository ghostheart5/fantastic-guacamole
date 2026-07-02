import 'package:fantastic_guacamole/features/reflect/state/reflect_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReflectController extends Notifier<ReflectState> {
  @override
  ReflectState build() => ReflectState.initial();
}
