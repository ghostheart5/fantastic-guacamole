import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_extended_domain_repository.dart';

class GetCoachMessages {
  const GetCoachMessages(this._repository);

  final IExtendedDomainRepository _repository;

  List<CoachMessage> call() => _repository.getCoachMessages();
}
