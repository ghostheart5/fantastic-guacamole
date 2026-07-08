import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/models/ai_credit_wallet.dart';

class CreditService {
  CreditService({required this._prefs});

  static const String _walletKey = 'ai_credit_wallet';
  static const int _freeAllowance = 20;
  static const int _freeDailyRefill = 20;
  static const int _premiumAllowance = 300;
  final SharedPrefsStore _prefs;

  Future<AiCreditWallet> loadWallet({required bool premium}) async {
    await _prefs.init();

    final String? raw = _prefs.load(_walletKey);
    final DateTime now = DateTime.now();

    AiCreditWallet wallet = raw == null || raw.trim().isEmpty
        ? _createWallet(premium: premium, now: now)
        : AiCreditWallet.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    if (premium && wallet.tier != 'premium') {
      wallet = _createWallet(premium: true, now: now);
    } else if (!premium && wallet.tier != 'free') {
      wallet = _createWallet(premium: false, now: now);
    }

    if (now.isAfter(wallet.resetAt)) {
      wallet = premium
          ? _createWallet(premium: true, now: now)
          : wallet.copyWith(
              balance: (wallet.balance + _freeDailyRefill).clamp(
                0,
                _freeAllowance,
              ),
              allowance: _freeAllowance,
              resetAt: now.add(const Duration(days: 1)),
              updatedAt: now,
            );
    }

    await _save(wallet);
    return wallet;
  }

  Future<AiCreditSpendResult> spend({
    required bool premium,
    required int amount,
  }) async {
    final AiCreditWallet wallet = await loadWallet(premium: premium);
    if (wallet.balance < amount) {
      return AiCreditSpendResult(wallet: wallet, allowed: false);
    }

    final DateTime now = DateTime.now();
    final AiCreditWallet updated = wallet.copyWith(
      balance: wallet.balance - amount,
      updatedAt: now,
    );
    await _save(updated);
    return AiCreditSpendResult(wallet: updated, allowed: true);
  }

  Future<void> refill({required bool premium}) async {
    await _save(_createWallet(premium: premium, now: DateTime.now()));
  }

  Future<void> _save(AiCreditWallet wallet) async {
    await _prefs.save(_walletKey, jsonEncode(wallet.toJson()));
  }

  AiCreditWallet _createWallet({required bool premium, required DateTime now}) {
    return premium
        ? AiCreditWallet(
            balance: _premiumAllowance,
            tier: 'premium',
            allowance: _premiumAllowance,
            resetAt: now.add(const Duration(days: 30)),
            updatedAt: now,
          )
        : AiCreditWallet(
            balance: _freeAllowance,
            tier: 'free',
            allowance: _freeAllowance,
            resetAt: now.add(const Duration(days: 1)),
            updatedAt: now,
          );
  }
}
