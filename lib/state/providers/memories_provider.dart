import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final memoriesProvider = NotifierProvider<MemoriesNotifier, List<MemoryEntity>>(
  MemoriesNotifier.new,
);

class MemoriesNotifier extends Notifier<List<MemoryEntity>> {
  static const _key = 'memories_v1';
  static const _maxEntries = 200;

  @override
  List<MemoryEntity> build() {
    final raw = SharedPrefsService.load(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => MemoryEntity.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> capture(String text) async {
    final memory = MemoryEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      date: DateTime.now(),
    );
    final updated = [memory, ...state];
    state = updated.length > _maxEntries
        ? updated.sublist(0, _maxEntries)
        : updated;
    await _persist();
  }

  Future<void> toggleStar(String id) async {
    state = state.map((m) {
      return m.id == id ? m.copyWith(starred: !m.starred) : m;
    }).toList();
    await _persist();
  }

  Future<void> _persist() async {
    await SharedPrefsService.save(
      _key,
      jsonEncode(state.map((m) => m.toJson()).toList()),
    );
  }
}
