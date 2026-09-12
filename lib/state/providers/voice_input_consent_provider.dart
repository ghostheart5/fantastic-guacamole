import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final voiceInputConsentStoreProvider = Provider<VoiceInputConsentStore>((ref) {
  final scope = ref.watch(accountStorageScopeProvider);
  final store = VoiceInputConsentStore(scope);
  ref.onDispose(store.invalidate);
  return store;
});

/// Local consent for this account and this version of the provider disclosure.
/// No audio, transcript or platform microphone permission is stored here.
class VoiceInputConsentStore {
  VoiceInputConsentStore(AccountStorageScope scope)
    : _key = scope.isWritable
          ? scope.namespace!.scopedKey('voice_provider_consent.v1')
          : null;

  final String? _key;
  int _revision = 0;
  bool _active = true;
  Future<void>? _writes;

  int get revision => _revision;
  bool isCurrent(int revision) => _active && revision == _revision;
  void invalidate() {
    _active = false;
    _revision++;
  }

  Future<bool> isApproved() async {
    if (_key == null || !_active) return false;
    try {
      if (_writes case final pending?) await pending;
      return (await SharedPreferences.getInstance()).getBool(_key) == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> remember(int revision) {
    return _writes = (_writes ?? Future<void>.value()).then((_) async {
      if (_key == null || !isCurrent(revision)) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        if (isCurrent(revision)) await prefs.setBool(_key, true);
      } catch (_) {
        // The current explicit approval remains valid for this use only.
      }
    });
  }

  Future<void> revoke() {
    _revision++;
    return _writes = (_writes ?? Future<void>.value())
        .then((_) async {
          if (_key == null) return;
          final prefs = await SharedPreferences.getInstance();
          if (!await prefs.remove(_key)) {
            throw StateError('Voice consent reset was not saved.');
          }
        })
        .catchError((Object _) {
          // Keep this instance fail-closed if persistence fails.
          _active = false;
          throw StateError('Voice consent reset was not saved.');
        });
  }
}
