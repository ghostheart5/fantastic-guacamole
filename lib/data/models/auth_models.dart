class FirebaseAuthException implements Exception {
  FirebaseAuthException({required this.code, this.message});

  final String code;
  final String? message;

  @override
  String toString() => 'FirebaseAuthException($code, $message)';
}

class User {
  const User({
    required this.id,
    this.email,
    this.displayName,
    required this.emailVerified,
    this.appMetadata = const <String, dynamic>{},
  });

  final String id;
  final String? email;
  final String? displayName;
  final bool emailVerified;
  final Map<String, dynamic> appMetadata;

  bool get hasInternalAdvisorAccess {
    if (appMetadata['chronospark_admin'] == true) {
      return true;
    }
    return _metadataRoles(appMetadata['chronospark_roles']).any(_isAdminRole) ||
        _metadataRoles(appMetadata['roles']).any(_isAdminRole) ||
        _isAdminRole(appMetadata['role']?.toString());
  }

  static Iterable<String> _metadataRoles(Object? raw) {
    if (raw is Iterable) {
      return raw
          .map((Object? value) => value?.toString().trim().toLowerCase() ?? '')
          .where((String value) => value.isNotEmpty);
    }
    if (raw is String) {
      return raw
          .split(',')
          .map((String value) => value.trim().toLowerCase())
          .where((String value) => value.isNotEmpty);
    }
    return const <String>[];
  }

  static bool _isAdminRole(String? raw) {
    final String value = raw?.trim().toLowerCase() ?? '';
    return value == 'admin' ||
        value == 'developer' ||
        value == 'product_admin' ||
        value == 'qa_admin';
  }
}

class UserCredential {
  const UserCredential({this.user});

  final User? user;
}

enum AccountDeletionDisposition { completed, pending }

class AccountDeletionResult {
  const AccountDeletionResult.completed({this.localCleanupCompleted = true})
    : disposition = AccountDeletionDisposition.completed,
      serverState = 'completed',
      statusTrackingAvailable = true;

  const AccountDeletionResult.pending({
    required this.serverState,
    this.localCleanupCompleted = true,
    this.statusTrackingAvailable = true,
  }) : disposition = AccountDeletionDisposition.pending;

  final AccountDeletionDisposition disposition;
  final String serverState;
  final bool localCleanupCompleted;
  final bool statusTrackingAvailable;

  bool get isCompleted => disposition == AccountDeletionDisposition.completed;
  bool get isPending => disposition == AccountDeletionDisposition.pending;
}
