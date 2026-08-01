import 'package:fantastic_guacamole/features/monetization/integration/monetization_actions_compat.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart'
    as feature_providers;
import 'package:fantastic_guacamole/features/monetization/providers/monetization_providers.dart'
    as legacy_providers;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final featureMonetizationActionsCompatProvider =
    Provider<MonetizationActionsCompat>((Ref ref) {
      return FeatureMonetizationActionsCompat(
        ref.read(feature_providers.monetizationConnectorActionsProvider),
      );
    });

final legacyMonetizationActionsCompatProvider =
    Provider<MonetizationActionsCompat>((Ref ref) {
      return LegacyMonetizationActionsCompat(
        ref.read(legacy_providers.monetizationConnectorActionsProvider),
      );
    });

final monetizationActionsCompatProvider = Provider<MonetizationActionsCompat>((
  Ref ref,
) {
  // Default to the feature stack while maintaining a legacy-compatible adapter.
  return ref.read(featureMonetizationActionsCompatProvider);
});
