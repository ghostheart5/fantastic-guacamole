import 'package:fantastic_guacamole/data/services/logs_service.dart';
import 'package:fantastic_guacamole/state/services/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final logsProvider = NotifierProvider<LogsController, AsyncValue<ChronoLogsPayload>>(
  LogsController.new,
);

class LogsController extends Notifier<AsyncValue<ChronoLogsPayload>> {
  @override
  AsyncValue<ChronoLogsPayload> build() {
    _load();
    return const AsyncValue.loading();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final payload = await ref.read(chronoLogsServiceProvider).load();
      state = AsyncValue.data(payload);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addCompletedTask(String task) async {
    await ref.read(chronoLogsServiceProvider).addCompletedTask(task);
    await _load();
  }
}
