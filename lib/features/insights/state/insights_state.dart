import 'package:fantastic_guacamole/features/insights/models/insights_models.dart';
import 'package:fantastic_guacamole/features/insights/services/insights_service.dart';
import 'package:fantastic_guacamole/state/controllers/controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InsightsState {
  const InsightsState({
    required this.bundle,
    required this.loading,
    this.error,
  });

  final InsightsBundle? bundle;
  final bool loading;
  final String? error;

  factory InsightsState.initial() =>
      const InsightsState(bundle: null, loading: false, error: null);
}

final insightsServiceProvider = Provider<InsightsService>(
  (ref) => const InsightsService(),
);

final insightsBundleProvider = Provider<InsightsBundle>((ref) {
  final si = ref.watch(siStateProvider);
  final service = ref.watch(insightsServiceProvider);
  return service.build(si);
});
