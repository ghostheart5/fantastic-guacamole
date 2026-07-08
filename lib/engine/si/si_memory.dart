import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIMemory {
  const SIMemory({this.entries = const <SISnapshot>[]});

  final List<SISnapshot> entries;

  SISnapshot? get latest => entries.isEmpty ? null : entries.first;

  SIMemory push(SISnapshot snapshot, {int maxEntries = 24}) {
    final List<SISnapshot> next = <SISnapshot>[snapshot, ...entries];
    return SIMemory(
      entries: next.length > maxEntries ? next.take(maxEntries).toList() : next,
    );
  }

  SIMemory clear() => const SIMemory();
}
