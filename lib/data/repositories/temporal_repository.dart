abstract class TemporalRepository {
  Future<List<double>> loadDayIntensity();
  Future<List<int>> loadWeekArc();
}
