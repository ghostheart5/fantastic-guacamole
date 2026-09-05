/// Backend selection is independent of production/debug and QA access.
enum BackendMode { cloud, local }

abstract final class BackendConfiguration {
  static const String configuredValue = String.fromEnvironment(
    'CHRONOSPARK_BACKEND_MODE',
    defaultValue: 'cloud',
  );

  static BackendMode? parse(String value) => switch (value.trim()) {
    'cloud' => BackendMode.cloud,
    'local' => BackendMode.local,
    _ => null,
  };

  static BackendMode? get mode => parse(configuredValue);
  static bool get isValid => mode != null;
  static bool get isLocal => mode == BackendMode.local;
  static bool get cloudServicesEnabled => mode == BackendMode.cloud;
}
