import 'package:fantastic_guacamole/domain/entities/subtask_entity.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final subtasksProvider =
    NotifierProvider<SubtasksNotifier, List<SubtaskEntity>>(
      SubtasksNotifier.new,
    );

final subtaskProvider = subtasksProvider;

final subtasksByParentTaskProvider =
    Provider.family<List<SubtaskEntity>, String>((
      Ref ref,
      String parentTaskId,
    ) {
      return ref
          .watch(subtasksProvider)
          .where((SubtaskEntity item) => item.parentTaskId == parentTaskId)
          .toList(growable: false);
    });

class SubtasksNotifier extends Notifier<List<SubtaskEntity>> {
  @override
  List<SubtaskEntity> build() {
    return ref.read(getSubtasksUseCaseProvider).call();
  }

  Future<void> add(SubtaskEntity subtask) async {
    await ref.read(createSubtaskUseCaseProvider).call(subtask);
    state = [
      subtask,
      ...state.where((SubtaskEntity item) => item.id != subtask.id),
    ];
  }

  Future<void> update(SubtaskEntity subtask) async {
    await ref.read(updateSubtaskUseCaseProvider).call(subtask);
    state = state
        .map((SubtaskEntity item) => item.id == subtask.id ? subtask : item)
        .toList(growable: false);
  }

  Future<void> complete(String id) async {
    SubtaskEntity? selected;
    for (final SubtaskEntity item in state) {
      if (item.id == id) {
        selected = item;
        break;
      }
    }
    if (selected == null) {
      return;
    }
    final SubtaskEntity completed = selected.complete();
    await ref.read(updateSubtaskUseCaseProvider).call(completed);
    state = state
        .map((SubtaskEntity item) => item.id == id ? completed : item)
        .toList(growable: false);
  }

  Future<void> remove(String id) async {
    await ref.read(deleteSubtaskUseCaseProvider).call(id);
    state = state
        .where((SubtaskEntity item) => item.id != id)
        .toList(growable: false);
  }

  Future<void> saveAll(List<SubtaskEntity> subtasks) async {
    await ref.read(saveSubtasksUseCaseProvider).call(subtasks);
    state = subtasks;
  }
}
