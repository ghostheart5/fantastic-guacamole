part of '../env.dart';

abstract final class _FeatureFlags {
  static const bool _enableMockLoginDefine = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_MOCK_LOGIN',
    // Mock authentication must always be explicitly enabled.
    defaultValue: false,
  );
  static const String _enableMockLoginRawDefine = String.fromEnvironment(
    'CHRONOSPARK_ENABLE_MOCK_LOGIN',
  );
  static const bool _hasEnableMockLoginDefine = bool.hasEnvironment(
    'CHRONOSPARK_ENABLE_MOCK_LOGIN',
  );
  static const bool _enableMockModeDefine = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_MOCK_MODE',
    defaultValue: false,
  );
  static const String _enableMockModeRawDefine = String.fromEnvironment(
    'CHRONOSPARK_ENABLE_MOCK_MODE',
  );
  static const bool _hasEnableMockModeDefine = bool.hasEnvironment(
    'CHRONOSPARK_ENABLE_MOCK_MODE',
  );
  static const bool _enablePaywallDisabledDefine = bool.fromEnvironment(
    'CHRONOSPARK_PAYWALL_DISABLED',
    defaultValue: false,
  );
  static const String _enablePaywallDisabledRawDefine = String.fromEnvironment(
    'CHRONOSPARK_PAYWALL_DISABLED',
  );
  static const bool _hasEnablePaywallDisabledDefine = bool.hasEnvironment(
    'CHRONOSPARK_PAYWALL_DISABLED',
  );
  static const bool _enableTesterFullAccessDefine = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS',
    defaultValue: false,
  );
  static const String _enableTesterFullAccessRawDefine = String.fromEnvironment(
    'CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS',
  );
  static const bool _hasEnableTesterFullAccessDefine = bool.hasEnvironment(
    'CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS',
  );
  static const bool _enableRuntimeFeatureFlagsDefine = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_RUNTIME_FEATURE_FLAGS',
    defaultValue: true,
  );
  static const String _enableRuntimeFeatureFlagsRawDefine =
      String.fromEnvironment('CHRONOSPARK_ENABLE_RUNTIME_FEATURE_FLAGS');
  static const bool _hasEnableRuntimeFeatureFlagsDefine = bool.hasEnvironment(
    'CHRONOSPARK_ENABLE_RUNTIME_FEATURE_FLAGS',
  );
  static const String _remoteConfigDefaultsJsonDefine = String.fromEnvironment(
    'CHRONOSPARK_REMOTE_CONFIG_JSON',
    defaultValue: '',
  );
  static const bool _hasRemoteConfigDefaultsJsonDefine = bool.hasEnvironment(
    'CHRONOSPARK_REMOTE_CONFIG_JSON',
  );
  static const bool _enableCloudSyncDefine = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_CLOUD_SYNC',
    defaultValue: false,
  );
  static const String _enableCloudSyncRawDefine = String.fromEnvironment(
    'CHRONOSPARK_ENABLE_CLOUD_SYNC',
  );
  static const bool _hasEnableCloudSyncDefine = bool.hasEnvironment(
    'CHRONOSPARK_ENABLE_CLOUD_SYNC',
  );

  static bool get enableMockLogin => Env._readRiskBool(
    'CHRONOSPARK_ENABLE_MOCK_LOGIN',
    _enableMockLoginDefine,
    defineProvided: _hasEnableMockLoginDefine,
    rawDefineValue: _enableMockLoginRawDefine,
  );

  static bool get enableMockMode => Env._readRiskBool(
    'CHRONOSPARK_ENABLE_MOCK_MODE',
    _enableMockModeDefine,
    defineProvided: _hasEnableMockModeDefine,
    rawDefineValue: _enableMockModeRawDefine,
  );

  static bool get enablePaywallDisabled => Env._readRiskBool(
    'CHRONOSPARK_PAYWALL_DISABLED',
    _enablePaywallDisabledDefine,
    defineProvided: _hasEnablePaywallDisabledDefine,
    rawDefineValue: _enablePaywallDisabledRawDefine,
  );

  static bool get enableTesterFullAccess => Env._readRiskBool(
    'CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS',
    _enableTesterFullAccessDefine,
    defineProvided: _hasEnableTesterFullAccessDefine,
    rawDefineValue: _enableTesterFullAccessRawDefine,
  );

  static bool get enableRuntimeFeatureFlags => Env._readBool(
    'CHRONOSPARK_ENABLE_RUNTIME_FEATURE_FLAGS',
    _enableRuntimeFeatureFlagsDefine,
    defineProvided: _hasEnableRuntimeFeatureFlagsDefine,
    rawDefineValue: _enableRuntimeFeatureFlagsRawDefine,
  );

  static String get remoteConfigDefaultsJson => Env._readString(
    'CHRONOSPARK_REMOTE_CONFIG_JSON',
    _remoteConfigDefaultsJsonDefine,
    defineProvided: _hasRemoteConfigDefaultsJsonDefine,
  );

  static bool get enableCloudSync => Env._readBool(
    'CHRONOSPARK_ENABLE_CLOUD_SYNC',
    _enableCloudSyncDefine,
    defineProvided: _hasEnableCloudSyncDefine,
    rawDefineValue: _enableCloudSyncRawDefine,
  );

  static bool resolveIsMockMode({
    required bool isProduction,
    required bool enableMockMode,
  }) {
    return !isProduction && enableMockMode;
  }

  static bool resolveIsPaywallDisabled({
    required bool isProduction,
    required bool enablePaywallDisabled,
    required bool isMockMode,
  }) {
    return !isProduction && (enablePaywallDisabled || isMockMode);
  }

  static bool resolveIsMockLoginEnabled({
    required bool isProduction,
    required bool isMockMode,
    required bool enableMockLogin,
  }) {
    return !isProduction && (isMockMode || enableMockLogin);
  }

  static bool resolveHasTesterFullAccess({
    required bool isProduction,
    required bool enableTesterFullAccess,
  }) {
    return !isProduction && enableTesterFullAccess;
  }

  static bool get isMockMode => resolveIsMockMode(
    isProduction: _BuildSettings.isProduction,
    enableMockMode: enableMockMode,
  );

  static bool get isPaywallDisabled => resolveIsPaywallDisabled(
    isProduction: _BuildSettings.isProduction,
    enablePaywallDisabled: enablePaywallDisabled,
    isMockMode: isMockMode,
  );

  static bool get isMockLoginEnabled => resolveIsMockLoginEnabled(
    isProduction: _BuildSettings.isProduction,
    isMockMode: isMockMode,
    enableMockLogin: enableMockLogin,
  );

  static bool get hasTesterFullAccess => resolveHasTesterFullAccess(
    isProduction: _BuildSettings.isProduction,
    enableTesterFullAccess: enableTesterFullAccess,
  );
}
