import 'package:fantastic_guacamole/features/monetization/integration/monetization_actions_compat.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart'
    as feature_providers;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final featureMonetizationActionsCompatProvider =
    Provider<MonetizationActionsCompat>((Ref ref) {
      return FeatureMonetizationActionsCompat(
        ref.read(feature_providers.monetizationConnectorActionsProvider),
      );
    });

final monetizationActionsCompatProvider = Provider<MonetizationActionsCompat>((
  Ref ref,
) {
  // Canonical path is the feature stack adapter.
  return ref.read(featureMonetizationActionsCompatProvider);
});
