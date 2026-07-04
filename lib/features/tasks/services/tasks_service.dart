import 'package:fantastic_guacamole/core/result/result.dart';
import 'package:fantastic_guacamole/core/services/si_engine_service.dart';
import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/features/tasks/models/tasks_models.dart';
import 'package:flutter/foundation.dart';

// Canonical tasks service — merged from tasks_service.dart + tasks_services.dart.
// SI decisions are injected optionally; existing callers still compile.

class TasksService {
  TasksService({SIEngineService? siEngine})
      : _siEngine = siEngine; // ignore: prefer_initializing_formals

  final SIEngineService? _siEngine;
  final List<TaskModel> _tasks = <TaskModel>[];

  Future<AppResult<List<TaskModel>>> loadTasks() async {
    return AppResult.success(List<TaskModel>.from(_tasks));
  }

  Future<AppResult<TaskModel>> createTask({
    required String title,
    String? description,
    DateTime? scheduledFor,
  }) async {
    String resolvedTitle = title;
    final SIEngineService? engine = _siEngine;
    if (engine != null && title.trim().isNotEmpty) {
      final SiDecisionEntity decision = await engine.think(
        'create task: $title',
      );
      if (decision.action.isNotEmpty) resolvedTitle = decision.action;
    }

    final TaskModel task = TaskModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: resolvedTitle,
      description: description,
      createdAt: DateTime.now(),
      scheduledFor: scheduledFor,
    );
    _tasks.add(task);
    return AppResult.success(task);
  }

  Future<AppResult<List<TaskModel>>> updateTask(TaskModel updated) async {
    final int index = _tasks.indexWhere((TaskModel t) => t.id == updated.id);
    if (index < 0) {
      return AppResult.failure('Task not found');
    }
    _tasks[index] = updated;
    return AppResult.success(List<TaskModel>.from(_tasks));
  }

  Future<AppResult<List<TaskModel>>> deleteTask(String id) async {
    _tasks.removeWhere((TaskModel t) => t.id == id);
    return AppResult.success(List<TaskModel>.from(_tasks));
  }
}

class TasksController extends ChangeNotifier {
  TasksController({required this._service});

  final TasksService _service;

  List<TaskModel> _tasks = <TaskModel>[];
  bool _loading = false;
  String? _error;

  List<TaskModel> get tasks => _tasks;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _setLoading(true);
    final AppResult<List<TaskModel>> result = await _service.loadTasks();
    if (result.isSuccess) {
      _tasks = result.data ?? <TaskModel>[];
      _error = null;
    } else {
      _error = result.message ?? 'Failed to load tasks';
    }
    _setLoading(false);
  }

  Future<void> addTask({
    required String title,
    String? description,
    DateTime? scheduledFor,
  }) async {
    _setLoading(true);
    final AppResult<TaskModel> result = await _service.createTask(
      title: title,
      description: description,
      scheduledFor: scheduledFor,
    );
    final TaskModel? createdTask = result.data;
    if (result.isSuccess && createdTask != null) {
      _tasks = <TaskModel>[..._tasks, createdTask];
      _error = null;
    } else {
      _error = result.message ?? 'Failed to create task';
    }
    _setLoading(false);
  }

  Future<void> updateStatus(String id, TaskStatus status) async {
    if (_tasks.isEmpty) return;
    final TaskModel task = _tasks.firstWhere(
      (TaskModel t) => t.id == id,
      orElse: () => _tasks.first,
    );
    await _persistUpdate(task.copyWith(status: status));
  }

  Future<void> markCompleted(String id) async {
    if (_tasks.isEmpty) return;
    final TaskModel task = _tasks.firstWhere(
      (TaskModel t) => t.id == id,
      orElse: () => _tasks.first,
    );
    await _persistUpdate(
      task.copyWith(
        status: TaskStatus.completed,
        completionCount: task.completionCount + 1,
      ),
    );
  }

  Future<void> markSkipped(String id) async {
    if (_tasks.isEmpty) return;
    final TaskModel task = _tasks.firstWhere(
      (TaskModel t) => t.id == id,
      orElse: () => _tasks.first,
    );
    await _persistUpdate(
      task.copyWith(status: TaskStatus.skipped, skipCount: task.skipCount + 1),
    );
  }

  Future<void> markDelayed(String id) async {
    if (_tasks.isEmpty) return;
    final TaskModel task = _tasks.firstWhere(
      (TaskModel t) => t.id == id,
      orElse: () => _tasks.first,
    );
    await _persistUpdate(
      task.copyWith(
        status: TaskStatus.delayed,
        delayCount: task.delayCount + 1,
      ),
    );
  }

  Future<void> deleteTask(String id) async {
    _setLoading(true);
    final AppResult<List<TaskModel>> result = await _service.deleteTask(id);
    if (result.isSuccess) {
      _tasks = result.data ?? <TaskModel>[];
      _error = null;
    } else {
      _error = result.message ?? 'Failed to delete task';
    }
    _setLoading(false);
  }

  Future<void> _persistUpdate(TaskModel updated) async {
    _setLoading(true);
    final AppResult<List<TaskModel>> result = await _service.updateTask(
      updated,
    );
    if (result.isSuccess) {
      _tasks = result.data ?? <TaskModel>[];
      _error = null;
    } else {
      _error = result.message ?? 'Failed to update task';
    }
    _setLoading(false);
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
