import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P1-3 monetization stack normalization contract', () {
    test('compat provider surface no longer exposes legacy provider token', () {
      final File file = File(
        'lib/features/monetization/providers/monetization_compat_providers.dart',
      );
      expect(file.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(file);

      expect(text.contains('legacyMonetizationActionsCompatProvider'), isFalse);
      expect(text.contains('featureMonetizationActionsCompatProvider'), isTrue);
      expect(text.contains('monetizationActionsCompatProvider'), isTrue);
      expect(text.contains('FeatureMonetizationActionsCompat'), isTrue);
    });

    test('monetization guard utilities depend on feature providers, not legacy providers', () {
      final File file = File(
        'lib/features/monetization/guards/monetization_guards.dart',
      );
      expect(file.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(file);

      expect(
        text.contains("import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart';"),
        isTrue,
      );
      expect(
        text.contains("import 'package:fantastic_guacamole/features/monetization/providers/monetization_providers.dart';"),
        isFalse,
      );
      expect(text.contains('Future<CreditConsumeResult> consumeCredits('), isTrue);
      expect(text.contains('aiCreditServiceProvider'), isTrue);
    });
  });
}
