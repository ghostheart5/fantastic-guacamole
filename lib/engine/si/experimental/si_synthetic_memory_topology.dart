class MemoryTopology {
  const MemoryTopology({
    required this.peaks,
    required this.valleys,
    required this.ridges,
    required this.basins,
    required this.tunnels,
  });

  final List<String> peaks;
  final List<String> valleys;
  final List<String> ridges;
  final List<String> basins;
  final List<String> tunnels;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'peaks': peaks,
      'valleys': valleys,
      'ridges': ridges,
      'basins': basins,
      'tunnels': tunnels,
    };
  }
}

class SyntheticMemoryTopology {
  const SyntheticMemoryTopology();

  MemoryTopology map({required List<String> history, required String mood}) {
    return MemoryTopology(
      peaks: history
          .where((String h) => h.toLowerCase().contains('focus'))
          .take(3)
          .toList(),
      valleys: history.where((String h) => h.length < 18).take(3).toList(),
      ridges: <String>['goal_to_task_ridge', 'task_to_reflection_ridge'],
      basins: <String>[if (mood == 'stressed') 'stress_basin'],
      tunnels: <String>['hidden_pattern_tunnel'],
    );
  }
}
