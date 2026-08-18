import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';

abstract interface class ITrajectoryForecastLedgerRepository {
  Future<List<TrajectoryForecastReceipt>> load();
  Future<bool> append(TrajectoryForecastReceipt receipt);
  Future<int> reconcileDue(TrajectoryBaseline current);
}
