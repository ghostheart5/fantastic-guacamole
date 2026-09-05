import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/data/services/contracts/password_recovery_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Remembers verified SDK recovery events independently of widget lifetimes.
/// No tokens or recovery flags are written to disk.
class SupabasePasswordRecovery {
  SupabasePasswordRecovery._(this._client) {
    _subscription = _client.auth.onAuthStateChange.listen(
      _onAuthState,
      // An offline refresh must not release a pending recovery gate.
      onError: (Object _, StackTrace _) {},
      onDone: () => unawaited(_changes.close()),
    );
  }

  static final Expando<SupabasePasswordRecovery> _instances =
      Expando<SupabasePasswordRecovery>();

  static SupabasePasswordRecovery forClient(sb.SupabaseClient client) =>
      _instances[client] ??= SupabasePasswordRecovery._(client);

  final sb.SupabaseClient _client;
  final StreamController<PasswordRecoveryState> _changes =
      StreamController<PasswordRecoveryState>.broadcast(sync: true);
  late final StreamSubscription<sb.AuthState> _subscription;
  PasswordRecoveryState _state = const PasswordRecoveryState.inactive();
  String? _sessionIdentity;
  int _revision = 0;

  PasswordRecoveryState get state => _state;

  Stream<PasswordRecoveryState> get changes =>
      Stream<PasswordRecoveryState>.multi((controller) {
        final subscription = _changes.stream.listen(
          controller.addSync,
          onDone: controller.closeSync,
        );
        controller.addSync(_state);
        controller.onCancel = subscription.cancel;
      });

  void _onAuthState(sb.AuthState event) {
    final sb.Session? session = event.session;
    if (event.event == sb.AuthChangeEvent.passwordRecovery &&
        session != null &&
        _sameSession(session, _client.auth.currentSession)) {
      _sessionIdentity = _identity(session);
      _publish(PasswordRecoveryState.pending(session.user.id, ++_revision));
      return;
    }
    if (!_state.isPending) return;
    // A sign-out can finish its asynchronous storage cleanup after a new
    // account has signed in. It must not dismiss that newer recovery session.
    if (event.event == sb.AuthChangeEvent.signedOut &&
        _client.auth.currentSession != null) {
      return;
    }
    if (event.event == sb.AuthChangeEvent.signedIn ||
        event.event == sb.AuthChangeEvent.signedOut ||
        session == null ||
        session.user.id != _state.userId ||
        _identity(session) != _sessionIdentity) {
      clear();
    }
  }

  int requireCurrentSession() {
    final sb.Session? session = _client.auth.currentSession;
    if (!_state.isPending ||
        session == null ||
        session.isExpired ||
        session.user.id != _state.userId ||
        _identity(session) != _sessionIdentity) {
      throw recoverySessionRequired();
    }
    return _state.revision;
  }

  void complete(int revision) {
    // An older request must never dismiss a newer recovery event.
    if (_state.revision == revision) clear();
  }

  void clear() {
    _sessionIdentity = null;
    _publish(const PasswordRecoveryState.inactive());
  }

  void _publish(PasswordRecoveryState state) {
    _state = state;
    if (!_changes.isClosed) _changes.add(state);
  }

  static bool _sameSession(sb.Session first, sb.Session? second) =>
      second != null &&
      first.user.id == second.user.id &&
      _identity(first) == _identity(second);

  static String _identity(sb.Session session) {
    // This claim is only an equality/correlation key after an SDK-verified
    // passwordRecovery event. It is never used as authentication authority.
    try {
      final parts = session.accessToken.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        );
        final Object? id = payload is Map ? payload['session_id'] : null;
        if (id is String && id.isNotEmpty) return id;
      }
    } on Object {
      // Older/nonstandard tokens remain bound to their exact value.
    }
    return session.accessToken;
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _changes.close();
  }
}
