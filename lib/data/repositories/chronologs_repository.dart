import '../services/chronologs_service.dart';

abstract class ChronologsRepository {
  Future<ChronoLogsPayload> load();
  Future<void> save(ChronoLogsPayload payload);
}
