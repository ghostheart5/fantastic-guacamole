class TemporalService {
  Future<List<double>> loadDayIntensity() async {
    return const <double>[0.3, 0.7, 0.4, 0.9, 0.5, 0.8, 0.6];
  }

  Future<List<int>> loadWeekArc() async {
    return const <int>[3, 4, 5, 2, 6, 5, 4];
  }
}
