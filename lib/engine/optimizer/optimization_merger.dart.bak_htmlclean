import 'package:fantastic_guacamole/engine/optimizer/optimization_config.dart';

class OptimizationMerger {
  const OptimizationMerger();

  OptimizationConfig merge(
    OptimizationConfig local,
    OptimizationConfig global,
  ) {
    return local.lerp(global, 0.3);
  }
}
