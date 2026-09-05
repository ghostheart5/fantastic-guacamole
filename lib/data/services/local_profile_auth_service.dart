import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';

/// One durable device profile. It has no password, email, cloud session, or
/// privileged metadata. Deletion is journaled before any data is removed so a
/// failed or interrupted cleanup can be retried without reopening partial data.
class LocalProfileAuthService implements AuthServiceContract {
  LocalProfileAuthService({
    required this._store,
    required this._onProfileDeleted,
    required this._onBeforeClosed,
  });

  static const String profileKey = 'chronospark_local_profile_v1';
  static final RegExp _idPattern = RegExp(r'^local-[a-f0-9]{32}$');
  final SecureStore _store;
  final Future<void> Function(String accountId) _onProfileDeleted;
  final Future<void> Function(String accountId) _onBeforeClosed;
  final StreamController<User?> _changes = StreamController<User?>.broadcast();
  Future<void>? _initialization;
  Future<void> _tail = Future<void>.value();
  User? _profile;
  User? _user;
  bool _deleting = false;

  bool get hasStoredProfile => _profile != null;
  bool get hasPendingDeletion => _deleting;
  String? get pendingDeletionAccountId => _deleting ? _profile?.id : null;

  Future<void> initialize() {
    return _initialization ??= _load().onError((
      Object error,
      StackTrace stack,
    ) {
      _initialization = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _load() async {
    final String? raw = await _store.readString(profileKey);
    if (raw == null) return;
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != 1 ||
        decoded['id'] is! String ||
        !_idPattern.hasMatch(decoded['id'] as String) ||
        decoded['name'] is! String ||
        !const <String>[
          'active',
          'closed',
          'deleting',
        ].contains(decoded['state'])) {
      throw const FormatException('Stored local profile is invalid.');
    }
    _profile = User.localProfile(
      id: decoded['id'] as String,
      displayName: decoded['name'] as String,
    );
    _deleting = decoded['state'] == 'deleting';
    _user = decoded['state'] == 'active' ? _profile : null;
  }

  Future<void> _save(User profile, String state) => _store.writeString(
    profileKey,
    jsonEncode(<String, Object?>{
      'version': 1,
      'id': profile.id,
      'name': profile.displayName ?? '',
      'state': state,
    }),
  );

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final Future<T> next = _tail.then((_) async {
      await initialize();
      return operation();
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<User> createProfile({String displayName = ''}) => _serialize(() async {
    if (_profile != null) throw StateError('A local profile already exists.');
    final String name = displayName.trim();
    if (name.length > 80) throw ArgumentError('Profile name is too long.');
    final Random random = Random.secure();
    final String id = List<String>.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final User profile = User.localProfile(id: 'local-$id', displayName: name);
    await _save(profile, 'active');
    _profile = _user = profile;
    _changes.add(profile);
    return profile;
  });

  Future<User> openProfile() => _serialize(() async {
    final User? profile = _profile;
    if (profile == null || _deleting) {
      throw StateError('No available local profile.');
    }
    await _save(profile, 'active');
    _user = profile;
    _changes.add(profile);
    return profile;
  });

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> authStateChanges() => Stream<User?>.multi((events) {
    StreamSubscription<User?>? subscription;
    bool canceled = false;
    events.onCancel = () async {
      canceled = true;
      await subscription?.cancel();
    };
    unawaited(
      initialize().then<void>(
        (_) {
          if (canceled) return;
          subscription = _changes.stream.listen(
            events.add,
            onError: events.addError,
            onDone: events.close,
          );
          events.add(_user);
        },
        onError: (Object error, StackTrace stack) {
          if (!canceled) {
            events.addError(error, stack);
            unawaited(events.close());
          }
        },
      ),
    );
  });

  @override
  Future<void> signOut() => _serialize(() async {
    final User? profile = _profile;
    if (profile == null || _deleting) return;
    await _onBeforeClosed(profile.id);
    await _save(profile, 'closed');
    _user = null;
    _changes.add(null);
  });

  @override
  Future<AccountDeletionResult> deleteCurrentAccount({
    required String password,
  }) => _serialize(() async {
    final User? profile = _profile;
    if (profile == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    if (!_deleting) {
      await _save(profile, 'deleting');
      _deleting = true;
    }
    try {
      await _onProfileDeleted(profile.id);
      await _store.delete(profileKey);
      _profile = null;
      _deleting = false;
      return const AccountDeletionResult.completed();
    } finally {
      _user = null;
      _changes.add(null);
    }
  });

  @override
  Future<User?> reloadCurrentUser() async {
    await initialize();
    return _user;
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => null;

  Never _unsupported() => throw FirebaseAuthException(
    code: 'operation-not-supported',
    message: 'Cloud account operations are unavailable for a local profile.',
  );

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async => _unsupported();
  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async => _unsupported();
  @override
  Future<UserCredential> signInWithGoogle() async => _unsupported();
  @override
  Future<UserCredential> signInWithGitHub() async => _unsupported();
  @override
  Future<void> sendPasswordReset(String email) async => _unsupported();
  @override
  Future<void> updatePassword({required String newPassword}) async =>
      _unsupported();
  @override
  Future<void> sendEmailVerification() async => _unsupported();
  @override
  Future<PendingAccountDeletionStatus?> readPendingAccountDeletion() async =>
      null;
  @override
  Future<AccountDeletionResult?> refreshPendingAccountDeletion() async =>
      _unsupported();
  @override
  Future<void> forgetPendingAccountDeletion() async => _unsupported();

  Future<void> dispose() => _changes.close();
}
