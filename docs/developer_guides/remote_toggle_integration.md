# Remote Toggle Integration

## Layering
- `data/services/remote_config_service.dart`: fetch + typed value access
- `data/repositories/feature_flag_repository.dart`: defaulting + mapping
- `state/providers/feature_flags_provider.dart`: app-facing read model
- `state/providers/ab_test_provider.dart`: experiment assignment read model

## Usage Pattern
1. Add default key/value in repository.
2. Load through provider in UI/controller/state layer.
3. Branch behavior with explicit fallback paths.
4. Keep kill switch support for high-risk capability.

## Validation
- Run `flutter analyze` on touched scope.
- Run `powershell -NoProfile -ExecutionPolicy Bypass -File check_architecture.ps1`.
