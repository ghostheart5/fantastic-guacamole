import 'package:fantastic_guacamole/features/user/state/user_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserController extends Notifier<UserState> {
  @override
  UserState build() => UserState.initial();
}
