import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistent trial counter storage with integrity checking via HMAC
class TrialCounterStore {
  TrialCounterStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _storageKey = 'trial_counters_v1';
  static const String _signatureKey = 'trial_counters_signature_v1';
  static const String _hmacSecret = 'chronospark_trial_integrity_2026';

  final FlutterSecureStorage _storage;

  /// Save trial counters with HMAC signature
  Future<void> saveCounters({
    required int temporalUses,
    required int siConsoleUses,
  }) async {
    final Map<String, dynamic> data = {
      'temporalUses': temporalUses,
      'siConsoleUses': siConsoleUses,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final String encoded = jsonEncode(data);
    final String signature = _computeSignature(encoded);

    await Future.wait([
      _storage.write(key: _storageKey, value: encoded),
      _storage.write(key: _signatureKey, value: signature),
    ]);
  }

  /// Load trial counters and verify integrity
  Future<({int temporalUses, int siConsoleUses})> loadCounters() async {
    final String? encoded = await _storage.read(key: _storageKey);
    final String? signature = await _storage.read(key: _signatureKey);

    if (encoded == null || signature == null) {
      // No stored data - return defaults
      return (temporalUses: 0, siConsoleUses: 0);
    }

    // Verify signature
    final String computedSignature = _computeSignature(encoded);
    if (signature != computedSignature) {
      // Signature mismatch - data tampered with
      // Fail-closed: reset to 0
      await clearCounters();
      return (temporalUses: 0, siConsoleUses: 0);
    }

    try {
      final Map<String, dynamic> data = jsonDecode(encoded);

      // Validate data structure
      if (data['temporalUses'] is! int ||
          data['siConsoleUses'] is! int) {
        await clearCounters();
        return (temporalUses: 0, siConsoleUses: 0);
      }

      // Check timestamp (reject if older than 1 year - stale data)
      final int timestamp = data['timestamp'] ?? 0;
      final int ageMs = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (ageMs > 365 * 24 * 60 * 60 * 1000) {
        await clearCounters();
        return (temporalUses: 0, siConsoleUses: 0);
      }

      return (
        temporalUses: (data['temporalUses'] as int).clamp(0, 100),
        siConsoleUses: (data['siConsoleUses'] as int).clamp(0, 100),
      );
    } catch (_) {
      // Corrupted data
      await clearCounters();
      return (temporalUses: 0, siConsoleUses: 0);
    }
  }

  /// Clear stored counters
  Future<void> clearCounters() async {
    await Future.wait([
      _storage.delete(key: _storageKey),
      _storage.delete(key: _signatureKey),
    ]);
  }

  String _computeSignature(String data) {
    final bytes = utf8.encode(data);
    final hmac = crypto.Hmac(crypto.sha256, utf8.encode(_hmacSecret));
    final digest = hmac.convert(bytes);
    return digest.toString();
  }
}

/// In-memory trial counter store for testing
class InMemoryTrialCounterStore extends TrialCounterStore {
  InMemoryTrialCounterStore();

  Map<String, dynamic> _data = {};

  @override
  Future<void> saveCounters({
    required int temporalUses,
    required int siConsoleUses,
  }) async {
    _data = {
      'temporalUses': temporalUses,
      'siConsoleUses': siConsoleUses,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  @override
  Future<({int temporalUses, int siConsoleUses})> loadCounters() async {
    if (_data.isEmpty) {
      return (temporalUses: 0, siConsoleUses: 0);
    }

    return (
      temporalUses: (_data['temporalUses'] as int?) ?? 0,
      siConsoleUses: (_data['siConsoleUses'] as int?) ?? 0,
    );
  }

  @override
  Future<void> clearCounters() async {
    _data.clear();
  }
}
