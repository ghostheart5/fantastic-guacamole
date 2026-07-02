class AppTheme {
  const AppTheme({required this.id, required this.name, this.isDark = true});

  final String id;
  final String name;
  final bool isDark;

  factory AppTheme.defaultTheme() => const AppTheme(id: 'dark', name: 'Dark');

  AppTheme copyWith({String? id, String? name, bool? isDark}) => AppTheme(
    id: id ?? this.id,
    name: name ?? this.name,
    isDark: isDark ?? this.isDark,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'isDark': isDark};

  factory AppTheme.fromJson(Map<String, dynamic> json) => AppTheme(
    id: json['id'] as String? ?? 'dark',
    name: json['name'] as String? ?? 'Dark',
    isDark: json['isDark'] as bool? ?? true,
  );
}
