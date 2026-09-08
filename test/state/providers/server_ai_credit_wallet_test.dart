import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/models/ai_credit_wallet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('purchased balances survive wallet copies and serialization', () {
    final wallet = serverAiCreditWallet({
      'balance': 415,
      'purchased_credits': 400,
      'period_credits': 20,
      'refunded_credit_debt': 3,
      'tier': 'free',
    });
    final restored = AiCreditWallet.fromJson(wallet.copyWith().toJson());
    expect(restored.balance, 415);
    expect(restored.purchasedCredits, 400);
    expect(restored.refundedCreditDebt, 3);
    expect(restored.allowance, 20);
  });
  test('maps the RLS-protected server wallet into the UI model', () {
    final wallet = serverAiCreditWallet(<String, dynamic>{
      'balance': 287,
      'tier': 'premium_monthly',
      'period_credits': 300,
      'period_ends_at': '2026-09-27T00:00:00.000Z',
      'updated_at': '2026-08-27T12:00:00.000Z',
    });

    expect(wallet.balance, 287);
    expect(wallet.allowance, 300);
    expect(wallet.tier, 'premium');
    expect(wallet.resetAt.toUtc(), DateTime.utc(2026, 9, 27));
    expect(wallet.updatedAt.toUtc(), DateTime.utc(2026, 8, 27, 12));
  });

  for (final tier in [
    'premium',
    'premium_monthly',
    'premium_yearly',
    'free',
    'unknown',
  ]) {
    test('normalizes server tier $tier for allowance display', () {
      final wallet = serverAiCreditWallet({
        'tier': tier,
        'balance': 19,
        'period_credits': 300,
      });
      expect(wallet.tier, tier.startsWith('premium') ? 'premium' : 'free');
    });
  }

  test('clamps malformed server balances instead of trusting them', () {
    final wallet = serverAiCreditWallet(<String, dynamic>{
      'balance': -4,
      'period_credits': -1,
    });

    expect(wallet.balance, 0);
    expect(wallet.allowance, 0);
  });
}
