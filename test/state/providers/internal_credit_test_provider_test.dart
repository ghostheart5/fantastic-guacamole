import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/features/settings/widgets/internal_credit_test_panel.dart';
import 'package:fantastic_guacamole/state/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/billing_availability_provider.dart';
import 'package:fantastic_guacamole/state/providers/internal_credit_test_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final testAccount = NotifierProvider<_Account, AccountStorageScope>(
  _Account.new,
);

class _Account extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() =>
      AccountStorageScope.authenticated('test-owner');
  void switchAccount() => state = AccountStorageScope.authenticated('second');
}

class _Profile extends PersonalizationProfileController {
  _Profile(this.consent);
  final bool consent;
  @override
  PersonalizationProfile build() =>
      PersonalizationProfile(externalAiAllowed: consent);
}

ProviderContainer createCreditContainer(
  CreditTestTransport transport, {
  bool consent = true,
  bool cohort = true,
  int Function()? balance,
}) {
  final container = ProviderContainer(
    overrides: [
      internalCreditTestEnabledProvider.overrideWithValue(cohort),
      accountStorageScopeProvider.overrideWith((ref) => ref.watch(testAccount)),
      personalizationProfileProvider.overrideWith(() => _Profile(consent)),
      internalCreditTestTransportProvider.overrideWithValue(transport),
      aiCreditWalletProvider.overrideWith(
        (ref) async => AiCreditWallet(
          balance: balance?.call() ?? 20,
          tier: 'free',
          allowance: 20,
          resetAt: DateTime.utc(2026, 9, 9),
          updatedAt: DateTime.utc(2026, 9, 8),
        ),
      ),
    ],
  );
  container.listen(internalCreditTestProvider, (_, _) {});
  return container;
}

CreditTestReply success(Map<String, dynamic> body) => (
  status: 200,
  data: {
    'requestId': body['requestId'],
    'creditsCharged': (body['prompt'] as String).length > 120 ? 2 : 1,
    'remainingCredits': 18,
    'message': 'Group fictional tools by purpose.',
  },
);

void main() {
  testWidgets('internal controls stay hidden outside the cohort', (
    tester,
  ) async {
    final container = createCreditContainer(
      (body) async => success(body),
      cohort: false,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: InternalCreditTestPanel()),
        ),
      ),
    );
    expect(find.text('Test 1 credit'), findsNothing);
  });

  testWidgets('consent-off controls cannot send a request', (tester) async {
    var calls = 0;
    final container = createCreditContainer((body) async {
      calls++;
      return success(body);
    }, consent: false);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: InternalCreditTestPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Test 1 credit'),
    );
    expect(button.onPressed, isNull);
    expect(calls, 0);
  });

  testWidgets(
    'visible two-credit action updates server balance at 320dp and 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(640, 960);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var balance = 20;
      final container = createCreditContainer((body) async {
        expect((body['prompt'] as String).length, greaterThan(120));
        balance -= 2;
        return (
          status: 200,
          data: {...success(body).data, 'remainingCredits': balance},
        );
      }, balance: () => balance);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(320, 480),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                body: SingleChildScrollView(child: InternalCreditTestPanel()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Test 2 credits'));
      await tester.tap(find.text('Test 2 credits'));
      await tester.pumpAndSettle();
      expect(find.text('Server credit balance: 18'), findsOneWidget);
      expect(
        find.textContaining('Server confirmed: 2 credit(s) used'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final denied in [
    (consent: false, cohort: true),
    (consent: true, cohort: false),
  ]) {
    test('denies requests for $denied', () async {
      var calls = 0;
      final container = createCreditContainer(
        (body) async {
          calls++;
          return success(body);
        },
        consent: denied.consent,
        cohort: denied.cohort,
      );
      addTearDown(container.dispose);
      await container.read(internalCreditTestProvider.notifier).run();
      expect(calls, 0);
      expect(
        container.read(internalCreditTestProvider).message,
        contains('consent are required'),
      );
    });
  }

  test(
    'uses synthetic input only and preserves request identity on replay',
    () async {
      final calls = <Map<String, dynamic>>[];
      final container = createCreditContainer((body) async {
        calls.add(body);
        if (calls.length == 3) {
          return (
            status: 409,
            data: {
              'requestId': body['requestId'],
              'error': 'request_completed',
            },
          );
        }
        return success(body);
      });
      addTearDown(container.dispose);
      final controller = container.read(internalCreditTestProvider.notifier);
      await controller.run();
      expect(
        container.read(internalCreditTestProvider).message,
        contains('1 credit(s) used'),
      );
      await controller.run(twoCredits: true);
      expect(
        container.read(internalCreditTestProvider).message,
        contains('2 credit(s) used'),
      );
      await controller.run(replay: true);
      expect(
        container.read(internalCreditTestProvider).message,
        contains('No second charge'),
      );
      expect(calls[0]['requestId'], isNot(calls[1]['requestId']));
      expect(calls[1], equals(calls[2]));
      for (final body in calls) {
        expect(body['history'], isEmpty);
        expect(body['context'], isEmpty);
        expect(body['allowExternalAi'], isTrue);
        expect(body.keys.toSet(), {
          'prompt',
          'history',
          'context',
          'personality',
          'allowExternalAi',
          'requestId',
        });
      }
    },
  );

  test(
    'double taps issue one request and account switches discard its result',
    () async {
      final pending = Completer<CreditTestReply>();
      var calls = 0;
      late Map<String, dynamic> request;
      final container = createCreditContainer((body) {
        calls++;
        request = body;
        return pending.future;
      });
      addTearDown(container.dispose);
      final controller = container.read(internalCreditTestProvider.notifier);
      final first = controller.run();
      await controller.run(twoCredits: true);
      expect(calls, 1);
      container.read(testAccount.notifier).switchAccount();
      await container.pump();
      pending.complete(success(request));
      await first;
      expect(container.read(internalCreditTestProvider).lastRequest, isNull);
      expect(
        container.read(internalCreditTestProvider).message,
        isNot(contains('Server confirmed')),
      );
    },
  );

  test(
    'insufficient credits and uncertain failures never claim a successful spend',
    () async {
      var status = 402;
      final container = createCreditContainer(
        (body) async =>
            (status: status, data: {'requestId': body['requestId']}),
      );
      addTearDown(container.dispose);
      await container.read(internalCreditTestProvider.notifier).run();
      expect(
        container.read(internalCreditTestProvider).message,
        contains('Insufficient credits'),
      );
      status = 503;
      await container
          .read(internalCreditTestProvider.notifier)
          .run(replay: true);
      expect(
        container.read(internalCreditTestProvider).message,
        contains('did not confirm'),
      );
    },
  );

  test('unmatched server response is not a confirmed debit', () async {
    final container = createCreditContainer(
      (body) async => (
        status: 200,
        data: {...success(body).data, 'requestId': 'other-request'},
      ),
    );
    addTearDown(container.dispose);
    await container.read(internalCreditTestProvider.notifier).run();
    expect(
      container.read(internalCreditTestProvider).message,
      isNot(contains('Server confirmed')),
    );
  });
}
