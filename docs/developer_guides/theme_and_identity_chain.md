<style>
a {
    text-decoration: none;
    color: #464feb;
}
tr th, tr td {
    border: 1px solid #e6e6e6;
}
tr th {
    background-color: #f5f5f5;
}
</style>

## Theme and identity chain

Theme chain:
UI/app root
  -> state/providers/theme_provider.dart
  -> domain/usecases/get_current_theme.dart
  -> domain/usecases/save_theme.dart
  -> domain/usecases/get_all_themes.dart
  -> domain/usecases/switch_theme.dart
  -> domain/interfaces/i_theme_repository.dart
  -> data/repositories/theme_repository.dart
  -> storage/shared prefs

Identity chain:
UI/profile + insights
  -> state/providers/identity_provider.dart
  -> domain/usecases/get_identity_profile.dart
  -> domain/usecases/save_identity_profile.dart
  -> domain/interfaces/i_identity_repository.dart
  -> data/repositories/identity_repository.dart
  -> secure storage

Notes:
- identityStateProvider remains the stable UI-facing API.
- identity_service.dart still owns ensureIdentity() behavior for runtime identity ID generation, but now depends on the domain interface rather than a concrete repository.
- app_root.dart now consumes currentThemeProvider so theme persistence is part of the live app path rather than dead architecture.
