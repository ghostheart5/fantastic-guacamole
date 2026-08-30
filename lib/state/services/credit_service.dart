import 'dart:convert';

import 'package:fantastic_guacamole/config/launch_containment.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/models/ai_credit_wallet.dart';

class CreditService {
  CreditService({
    required this._prefs,
    this.spendingEnabled = LaunchContainment.creditSpendingEnabled,
  });

  static const String _walletKey = 'ai_credit_wallet';
  static const int _freeAllowance = 20;
  static const int _freeDailyRefill = 20;
  static const int _premiumAllowance = 300;
  final SharedPrefsStore _prefs;
  final bool spendingEnabled;

  Future<AiCreditWallet> loadWallet({required bool premium}) async {
    await _prefs.init();

    final String? raw = _prefs.load(_walletKey);
    final DateTime now = DateTime.now();

    final AiCreditWallet? storedWallet = _readStoredWallet(raw);
    AiCreditWallet wallet =
        storedWallet ?? _createWallet(premium: premium, now: now);

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
    if (!spendingEnabled) {
      return AiCreditSpendResult(wallet: wallet, allowed: false);
    }
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

  /// Returns credits taken by [spend] for work that produced no result.
  ///
  /// Credits are debited before the request is issued, so a timeout, a proxy
  /// failure, or a superseded request would otherwise bill the user for a
  /// response they never received. The refund is clamped to the wallet
  /// allowance so a repeated refund cannot mint credits.
  Future<AiCreditWallet> refund({
    required bool premium,
    required int amount,
  }) async {
    final AiCreditWallet wallet = await loadWallet(premium: premium);
    if (amount <= 0) {
      return wallet;
    }
    final AiCreditWallet updated = wallet.copyWith(
      balance: (wallet.balance + amount).clamp(0, wallet.allowance),
      updatedAt: DateTime.now(),
    );
    await _save(updated);
    return updated;
  }

  Future<void> refill({required bool premium}) async {
    await _save(_createWallet(premium: premium, now: DateTime.now()));
  }

  Future<void> _save(AiCreditWallet wallet) async {
    await _prefs.save(_walletKey, jsonEncode(wallet.toJson()));
  }

  AiCreditWallet? _readStoredWallet(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Invalid AI credit wallet payload.');
      }
      return AiCreditWallet.fromJson(
        decoded.map<String, dynamic>(
          (Object? key, Object? value) => MapEntry(key.toString(), value),
        ),
      );
    } on FormatException {
      return null;
    }
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
