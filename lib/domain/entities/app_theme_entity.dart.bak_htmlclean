class AppThemeEntity {
  const AppThemeEntity({
    required this.id,
    required this.name,
    this.isDark = true,
  });

  final String id;
  final String name;
  final bool isDark;

  factory AppThemeEntity.defaultTheme() =>
      const AppThemeEntity(id: 'dark', name: 'Dark');

  factory AppThemeEntity.light() =>
      const AppThemeEntity(id: 'light', name: 'Light', isDark: false);

  factory AppThemeEntity.dark() =>
      const AppThemeEntity(id: 'dark', name: 'Dark', isDark: true);

  AppThemeEntity copyWith({String? id, String? name, bool? isDark}) {
    return AppThemeEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      isDark: isDark ?? this.isDark,
    );
  }

  // Domain behavior
  AppThemeEntity toggle() => copyWith(isDark: !isDark);

  bool get isLight => !isDark;

  void validate() {
    if (name.trim().isEmpty) {
      throw StateError('Theme must have a name');
    }
  }
}
