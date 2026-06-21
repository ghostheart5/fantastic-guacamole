import '../services/temporal_service.dart';
import 'temporal_repository.dart';

class TemporalRepositoryImpl implements TemporalRepository {
  TemporalRepositoryImpl({TemporalService? service})
    : _service = service ?? TemporalService();

  final TemporalService _service;

  @override
  Future<List<double>> loadDayIntensity() {
    return _service.loadDayIntensity();
  }

  @override
  Future<List<int>> loadWeekArc() {
    return _service.loadWeekArc();
  }
}
