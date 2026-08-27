import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(wallet.tier, 'premium_monthly');
    expect(wallet.resetAt.toUtc(), DateTime.utc(2026, 9, 27));
    expect(wallet.updatedAt.toUtc(), DateTime.utc(2026, 8, 27, 12));
  });

  test('clamps malformed server balances instead of trusting them', () {
    final wallet = serverAiCreditWallet(<String, dynamic>{
      'balance': -4,
      'period_credits': -1,
    });

    expect(wallet.balance, 0);
    expect(wallet.allowance, 0);
  });
}
