import 'package:fantastic_guacamole/core/errors/app_result.dart';
import 'package:fantastic_guacamole/state/auth/auth_gateway_support.dart';

class AuthFailure extends AppFailure {
  const AuthFailure(super.message);
}

class SettingsActions {
  SettingsActions(this._authService);

  final AuthServiceContract _authService;

  Future<Result<void>> signOut() async {
    try {
      await _authService.signOut();
      return const Result.ok(null);
    } on FirebaseAuthException catch (error) {
      return Result.err(AuthFailure(_mapDeleteError(error.code)));
    } on Exception {
      return const Result.err(
        UnexpectedFailure('Could not sign out right now. Please try again.'),
      );
    }
  }

  Future<Result<void>> deleteAccount({required String password}) async {
    try {
      await _authService.deleteCurrentAccount(password: password);
      return const Result.ok(null);
    } on FirebaseAuthException catch (error) {
      return Result.err(AuthFailure(_mapDeleteError(error.code)));
    } on Exception {
      return const Result.err(
        UnexpectedFailure(
          'Could not delete account right now. Please try again.',
        ),
      );
    }
  }

  static String _mapDeleteError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a moment and try again.';
      case 'user-token-expired':
      case 'requires-recent-login':
        return 'For security, sign in again and retry account deletion.';
      case 'no-current-user':
        return 'No signed-in account found.';
      case 'missing-password':
        return 'Password is required to delete the account.';
      default:
        return 'Account deletion failed. Please try again.';
    }
  }
}
