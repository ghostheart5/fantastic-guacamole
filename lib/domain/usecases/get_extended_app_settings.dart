import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_extended_domain_repository.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Workspace
///
/// Extended-domain read. Registered as getExtendedAppSettingsUseCaseProvider.
class GetExtendedAppSettings {
  const GetExtendedAppSettings(this._repository);

  final IExtendedDomainRepository _repository;

  List<AppSetting> call() => _repository.getSettings();
}
