import 'dart:async';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/notes_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Explicit, temporary opt-in. Note bodies never enter general memory or SI.
final planningNoteSelectionProvider =
    NotifierProvider<PlanningNoteSelection, String?>(PlanningNoteSelection.new);

class PlanningNoteSelection extends Notifier<String?> {
  Timer? _expiry;
  @override
  String? build() {
    ref.watch(accountStorageScopeProvider);
    _expiry?.cancel();
    ref.onDispose(() => _expiry?.cancel());
    return null;
  }

  void select(String id) {
    if (!ref.read(accountStorageScopeProvider).isWritable ||
        id.trim().isEmpty) {
      return;
    }
    _expiry?.cancel();
    state = id;
    _expiry = Timer(const Duration(hours: 2), clear);
  }

  void clear() {
    _expiry?.cancel();
    state = null;
  }
}

final selectedPlanningNoteProvider = FutureProvider<NoteEntity?>((ref) async {
  final scope = ref.watch(accountStorageScopeProvider);
  final id = ref.watch(planningNoteSelectionProvider);
  if (!scope.isWritable || id == null) return null;
  final notes = await ref.watch(notesProvider.future);
  if (!ref.mounted ||
      ref.read(accountStorageScopeProvider).v2Namespace != scope.v2Namespace) {
    return null;
  }
  return notes.where((note) => note.id == id && !note.isArchived).firstOrNull;
});
