import 'package:fantastic_guacamole/features/identity/state/identity_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IdentityController extends Notifier<IdentityState> {
  @override
  IdentityState build() => IdentityState.initial();
}
