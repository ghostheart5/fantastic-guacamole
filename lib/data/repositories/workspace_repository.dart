// Dart SDK imports.
import 'dart:convert';

// Package imports.
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/workspace_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_workspace_repository.dart';

class WorkspaceRepository implements IWorkspaceRepository {
  WorkspaceRepository(this._store);

  static const String _workspaceKey = 'workspace_entity_v1';
  final SecureStore _store;

  @override
  Future<WorkspaceEntity?> getWorkspace() async {
    final String? raw = await _store.readString(_workspaceKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final DateTime updatedAt =
        DateTime.tryParse((decoded['updatedAt'] as String?) ?? '') ??
        DateTime.now();

    final Map<String, String> metadata = <String, String>{};
    final dynamic rawMetadata = decoded['metadata'];
    if (rawMetadata is Map) {
      rawMetadata.forEach((dynamic key, dynamic value) {
        metadata[key.toString()] = value.toString();
      });
    }

    return WorkspaceEntity(
      id: (decoded['id'] as String?) ?? '',
      name: (decoded['name'] as String?) ?? 'Workspace',
      updatedAt: updatedAt,
      activeModule: (decoded['activeModule'] as String?) ?? 'creator',
      metadata: metadata,
    );
  }

  @override
  Future<void> saveWorkspace(WorkspaceEntity workspace) {
    return _store.writeString(
      _workspaceKey,
      jsonEncode(<String, dynamic>{
        'id': workspace.id,
        'name': workspace.name,
        'updatedAt': workspace.updatedAt.toIso8601String(),
        'activeModule': workspace.activeModule,
        'metadata': workspace.metadata,
      }),
    );
  }

  @override
  Future<void> switchWorkspace(String id) async {
    final WorkspaceEntity current =
        await getWorkspace() ??
        WorkspaceEntity(id: id, name: 'Workspace', updatedAt: DateTime.now());
    await saveWorkspace(current.copyWith(id: id, updatedAt: DateTime.now()));
  }
}
