import 'operation_cancellation.dart';

class TemporalService {
  Future<List<double>> loadDayIntensity({CancellationToken? cancellationToken}) async {
    cancellationToken.throwIfCancelled();
    return const <double>[0.3, 0.7, 0.4, 0.9, 0.5, 0.8, 0.6];
  }

  Future<List<int>> loadWeekArc({CancellationToken? cancellationToken}) async {
    cancellationToken.throwIfCancelled();
    return const <int>[3, 4, 5, 2, 6, 5, 4];
  }
}
