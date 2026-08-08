import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_extended_domain_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Workspace
///
/// Extended-domain write. Registered as saveExtendedAppSettingUseCaseProvider.
class SaveExtendedAppSetting {
  const SaveExtendedAppSetting(this._repository);

  final IExtendedDomainRepository _repository;

  Future<void> call(AppSetting entity) => _repository.saveAppSetting(entity);
}
