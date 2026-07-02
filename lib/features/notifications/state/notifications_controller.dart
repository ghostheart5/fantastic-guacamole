import 'package:fantastic_guacamole/features/notifications/state/notifications_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationsController extends Notifier<NotificationsState> {
  @override
  NotificationsState build() => NotificationsState.initial();
}
