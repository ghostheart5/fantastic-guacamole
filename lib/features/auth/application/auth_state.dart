import 'package:fantastic_guacamole/features/auth/domain/core/failure.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_session_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_user_entity.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  const AuthState({
    required this.status,
    this.session,
    this.user,
    this.failure,
    required this.lastUpdated,
  });

  factory AuthState.initial() {
    return AuthState(
      status: AuthStatus.initial,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final AuthStatus status;
  final AuthSessionEntity? session;
  final AuthUserEntity? user;
  final AuthFailure? failure;
  final DateTime lastUpdated;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isBusy => status == AuthStatus.loading;
  bool get hasError => failure != null;

  AuthState copyWith({
    AuthStatus? status,
    AuthSessionEntity? session,
    AuthUserEntity? user,
    AuthFailure? failure,
    DateTime? lastUpdated,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      user: user ?? this.user,
      failure: failure ?? this.failure,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
