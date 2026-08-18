import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';

enum AccountStorageScopeState { signedOut, authenticated, unsafe }

/// The only local persistence scope states usable by later repositories.
final class AccountStorageScope {
  const AccountStorageScope._({
    required this.state,
    this.namespace,
  });

  const AccountStorageScope.signedOut()
    : state = AccountStorageScopeState.signedOut,
      namespace = const AccountStorageNamespace.signedOut();

  const AccountStorageScope.unsafe()
    : state = AccountStorageScopeState.unsafe,
      namespace = null;

  factory AccountStorageScope.authenticated(String rawUserId) {
    return AccountStorageScope._(
      state: AccountStorageScopeState.authenticated,
      namespace: AccountStorageNamespace.authenticated(rawUserId),
    );
  }

  final AccountStorageScopeState state;
  final AccountStorageNamespace? namespace;

  bool get isAuthenticated => state == AccountStorageScopeState.authenticated;
  bool get isWritable => isAuthenticated;
  String? get rawUserId => namespace?.rawUserId;
  String? get v2Namespace => namespace?.v2Scope;
  String? get legacyV1Candidate => namespace?.legacyV1Scope;
}
