enum AppFlavor {
  development('dev'),
  testing('test'),
  staging('staging'),
  production('prod');

  const AppFlavor(this.value);

  final String value;

  bool get isProduction => this == AppFlavor.production;

  static AppFlavor parse(String value) {
    final String normalized = value.trim().toLowerCase();
    return AppFlavor.values.firstWhere(
      (AppFlavor flavor) => flavor.value == normalized,
      orElse: () => AppFlavor.development,
    );
  }
}
