import 'package:fantastic_guacamole/tutorial/tutorial_models.dart';
import 'package:flutter/services.dart';

class TutorialAssetLoader {
  const TutorialAssetLoader();

  Future<TutorialDefinition> load(String path) async {
    final String raw = await rootBundle.loadString(path);
    return TutorialDefinition.decode(raw);
  }

  Future<List<TutorialDefinition>> loadAll(List<String> paths) async {
    final List<TutorialDefinition> definitions = <TutorialDefinition>[];

    for (final String path in paths) {
      definitions.add(await load(path));
    }

    return definitions;
  }
}
