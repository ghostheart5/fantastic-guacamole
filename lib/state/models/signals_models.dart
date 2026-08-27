import 'package:fantastic_guacamole/state/models/signal_model.dart';

class SignalsBundle {
  const SignalsBundle({
    required this.items,
    required this.summary,
    required this.healthScore,
  });

  final List<Signal> items;
  final String summary;
  final double healthScore;
}
