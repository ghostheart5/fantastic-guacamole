import 'package:fantastic_guacamole/engine/advisor/product_advisor_engine.dart';
import 'package:fantastic_guacamole/features/admin/ui/product_advisor_screen.dart';
import 'package:fantastic_guacamole/state/providers/advisor_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows stable error copy without raw exception details', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productInsightsProvider.overrideWith(
            (ref) async => throw StateError('raw-secret-token path=/tmp/private'),
          ),
        ],
        child: const MaterialApp(home: ProductAdvisorScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('Unable to load advisor insights.\nTry refreshing or check logs for details.'), findsOneWidget);
    expect(find.textContaining('raw-secret-token'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);
  });

  testWidgets('shows fallback warning and still renders insights', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productInsightsProvider.overrideWith(
            (ref) async => const ProductInsightsState(
              insights: [
                ProductInsight(
                  issue: 'Fallback issue',
                  cause: 'Source unavailable',
                  recommendation: 'Retry later',
                ),
              ],
              isFallback: true,
              warningMessage:
                  'Advisor insights are running in fallback mode.\nSome source data could not be loaded.',
            ),
          ),
        ],
        child: const MaterialApp(home: ProductAdvisorScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Advisor insights are running in fallback mode.\nSome source data could not be loaded.'), findsOneWidget);
    expect(find.text('Fallback issue'), findsOneWidget);
  });
}
