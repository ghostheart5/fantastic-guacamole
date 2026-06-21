import '../services/chronologs_service.dart';
import 'chronologs_repository.dart';

class ChronologsRepositoryImpl implements ChronologsRepository {
  ChronologsRepositoryImpl({ChronoLogsService? service})
    : _service = service ?? ChronoLogsService();

  final ChronoLogsService _service;

  @override
  Future<ChronoLogsPayload> load() {
    return _service.load();
  }

  @override
  Future<void> save(ChronoLogsPayload payload) {
    return _service.save(payload);
  }
}
