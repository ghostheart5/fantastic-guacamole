enum HealthStatus { healthy, degraded, critical }

class SystemHealth {
  const SystemHealth({
    this.status = HealthStatus.healthy,
    this.storageOk = true,
    this.engineOk = true,
    this.networkOk = true,
    this.lastChecked,
  });

  final HealthStatus status;
  final bool storageOk;
  final bool engineOk;
  final bool networkOk;
  final DateTime? lastChecked;

  bool get isHealthy => status == HealthStatus.healthy;

  SystemHealth copyWith({
    HealthStatus? status,
    bool? storageOk,
    bool? engineOk,
    bool? networkOk,
  }) {
    return SystemHealth(
      status: status ?? this.status,
      storageOk: storageOk ?? this.storageOk,
      engineOk: engineOk ?? this.engineOk,
      networkOk: networkOk ?? this.networkOk,
      lastChecked: DateTime.now(),
    );
  }

  static SystemHealth evaluate({
    required bool storageOk,
    required bool engineOk,
    required bool networkOk,
  }) {
    final HealthStatus status;
    if (storageOk && engineOk && networkOk) {
      status = HealthStatus.healthy;
    } else if (!storageOk || !engineOk) {
      status = HealthStatus.critical;
    } else {
      status = HealthStatus.degraded;
    }
    return SystemHealth(
      status: status,
      storageOk: storageOk,
      engineOk: engineOk,
      networkOk: networkOk,
      lastChecked: DateTime.now(),
    );
  }
}
