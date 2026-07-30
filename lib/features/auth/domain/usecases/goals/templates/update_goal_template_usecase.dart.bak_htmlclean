import 'package:fantastic_guacamole/domain/entities/template_entity.dart';

class UpdateGoalTemplateUsecase {
  const UpdateGoalTemplateUsecase();

  TemplateEntity call({
    required TemplateEntity template,
    String? name,
    String? description,
  }) {
    return template.copyWith(
      name: name,
      description: description,
      updatedAt: DateTime.now(),
    );
  }
}
