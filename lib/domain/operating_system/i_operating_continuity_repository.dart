// CHRONOSPARK-CLASS: SHIPPING | Feature: Operating continuity
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';

abstract interface class IOperatingContinuityRepository {
  Future<List<OperatingSnapshot>> loadHistory(String accountScope);
  Future<void> saveSnapshot(String accountScope, OperatingSnapshot snapshot);
  Future<String?> loadAcknowledgedSnapshotId(String accountScope);
  Future<void> acknowledge(String accountScope, String snapshotId);
}
