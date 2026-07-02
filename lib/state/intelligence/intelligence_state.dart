class EnvironmentState {
  const EnvironmentState({
    required this.appName,
    required this.appFlavor,
    required this.isProduction,
    required this.isSupabaseConfigured,
  });

  final String appName;
  final String appFlavor;
  final bool isProduction;
  final bool isSupabaseConfigured;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'appName': appName,
      'appFlavor': appFlavor,
      'isProduction': isProduction,
      'isSupabaseConfigured': isSupabaseConfigured,
    };
  }
}

class FeatureFlagsState {
  const FeatureFlagsState({
    required this.verboseLogs,
    required this.analyticsEnabled,
    required this.mockMode,
    required this.mockLoginEnabled,
    required this.paywallDisabled,
    required this.testerFullAccess,
  });

  final bool verboseLogs;
  final bool analyticsEnabled;
  final bool mockMode;
  final bool mockLoginEnabled;
  final bool paywallDisabled;
  final bool testerFullAccess;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'verboseLogs': verboseLogs,
      'analyticsEnabled': analyticsEnabled,
      'mockMode': mockMode,
      'mockLoginEnabled': mockLoginEnabled,
      'paywallDisabled': paywallDisabled,
      'testerFullAccess': testerFullAccess,
    };
  }
}

class MockLoginConfigState {
  const MockLoginConfigState({required this.email, required this.password});

  final String email;
  final String password;

  bool get isConfigured => email.trim().isNotEmpty && password.isNotEmpty;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'emailConfigured': email.trim().isNotEmpty,
      'passwordConfigured': password.isNotEmpty,
      'isConfigured': isConfigured,
    };
  }
}

class AuthStateSnapshot {
  const AuthStateSnapshot({required this.hasMockSession, required this.hasAuthenticatedUser});

  final bool hasMockSession;
  final bool hasAuthenticatedUser;

  bool get isAuthenticated => hasMockSession || hasAuthenticatedUser;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'hasMockSession': hasMockSession,
      'hasAuthenticatedUser': hasAuthenticatedUser,
      'isAuthenticated': isAuthenticated,
    };
  }
}

class IntelligenceState {
  const IntelligenceState({
    required this.environment,
    required this.flags,
    required this.auth,
    required this.mockLogin,
  });

  final EnvironmentState environment;
  final FeatureFlagsState flags;
  final AuthStateSnapshot auth;
  final MockLoginConfigState mockLogin;

  bool get paywallEnabled => !flags.paywallDisabled && !flags.testerFullAccess;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'environment': environment.toMap(),
      'flags': flags.toMap(),
      'auth': auth.toMap(),
      'mockLogin': mockLogin.toMap(),
      'paywallEnabled': paywallEnabled,
    };
  }
}
