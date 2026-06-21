import '../entities/temporal_block.dart';

abstract class TemporalRepository {
  Future<List<TemporalBlock>> getDayBlocks();
}
