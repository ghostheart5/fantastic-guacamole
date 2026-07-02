import 'package:fantastic_guacamole/features/logs/state/logs_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LogsController extends Notifier<LogsState> {
  @override
  LogsState build() => LogsState.initial();
}
