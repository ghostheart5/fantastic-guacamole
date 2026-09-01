enum AppFlavor {
  development('dev'),
  testing('test'),
  qualityAssurance('qa'),
  staging('staging'),
  production('prod');

  const AppFlavor(this.value);

  final String value;

  bool get isProduction => this == AppFlavor.production;

  static AppFlavor parse(String value) {
    return tryParse(value) ?? AppFlavor.development;
  }

  /// Strict parse: returns null for any unrecognised value instead of silently
  /// degrading to [AppFlavor.development].
  ///
  /// [parse] is kept unchanged for existing callers, but security decisions
  /// must use this so a typo (e.g. "production" instead of "prod") cannot
  /// quietly turn production hardening off. See `Env.resolveIsProduction`.
  static AppFlavor? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    // Accept the natural long spelling of the production flavor.
    if (normalized == 'production') {
      return AppFlavor.production;
    }
    for (final AppFlavor flavor in AppFlavor.values) {
      if (flavor.value == normalized) {
        return flavor;
      }
    }
    return null;
  }
}
