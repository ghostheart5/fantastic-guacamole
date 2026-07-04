import 'package:fantastic_guacamole/core/storage/shared_prefs_service.dart';

class LocalMetricsAccumulator {
  const LocalMetricsAccumulator();

  static const _kDate = 'lma_date';
  static const _kFocusSessions = 'lma_focus_sessions';
  static const _kFocusCompleted = 'lma_focus_completed';
  static const _kTasksCreated = 'lma_tasks_created';
  static const _kTasksCompleted = 'lma_tasks_completed';
  static const _kFocusSeconds = 'lma_focus_seconds';
  static const _kMomentumPeak = 'lma_momentum_peak';

  String _todayIso() => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _resetIfNewDay() async {
    final saved = SharedPrefsService.load(_kDate);
    final today = _todayIso();
    if (saved == today) return;
    await SharedPrefsService.save(_kDate, today);
    await SharedPrefsService.save(_kFocusSessions, '0');
    await SharedPrefsService.save(_kFocusCompleted, '0');
    await SharedPrefsService.save(_kTasksCreated, '0');
    await SharedPrefsService.save(_kTasksCompleted, '0');
    await SharedPrefsService.save(_kFocusSeconds, '0');
    await SharedPrefsService.save(_kMomentumPeak, '0.0');
  }

  int _loadInt(String key) =>
      int.tryParse(SharedPrefsService.load(key) ?? '0') ?? 0;

  double _loadDouble(String key) =>
      double.tryParse(SharedPrefsService.load(key) ?? '0.0') ?? 0.0;

  Future<void> recordFocusSession({
    required bool completed,
    required int durationSeconds,
  }) async {
    await _resetIfNewDay();
    await SharedPrefsService.save(
      _kFocusSessions,
      (_loadInt(_kFocusSessions) + 1).toString(),
    );
    if (completed) {
      await SharedPrefsService.save(
        _kFocusCompleted,
        (_loadInt(_kFocusCompleted) + 1).toString(),
      );
    }
    await SharedPrefsService.save(
      _kFocusSeconds,
      (_loadInt(_kFocusSeconds) + durationSeconds).toString(),
    );
  }

  Future<void> recordTaskCompleted() async {
    await _resetIfNewDay();
    await SharedPrefsService.save(
      _kTasksCompleted,
      (_loadInt(_kTasksCompleted) + 1).toString(),
    );
  }

  Future<void> recordTaskCreated() async {
    await _resetIfNewDay();
    await SharedPrefsService.save(
      _kTasksCreated,
      (_loadInt(_kTasksCreated) + 1).toString(),
    );
  }

  Future<void> recordMomentumPeak(double peak) async {
    await _resetIfNewDay();
    final current = _loadDouble(_kMomentumPeak);
    if (peak > current) {
      await SharedPrefsService.save(_kMomentumPeak, peak.toString());
    }
  }

  Future<Map<String, dynamic>> snapshot() async {
    await _resetIfNewDay();
    return {
      'date': _todayIso(),
      'focus_sessions': _loadInt(_kFocusSessions),
      'focus_completed': _loadInt(_kFocusCompleted),
      'tasks_created': _loadInt(_kTasksCreated),
      'tasks_completed': _loadInt(_kTasksCompleted),
      'total_focus_seconds': _loadInt(_kFocusSeconds),
      'momentum_peak': _loadDouble(_kMomentumPeak),
    };
  }
}
