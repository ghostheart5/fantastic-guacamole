import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

extension CreatorFormKindDisplay on CreatorFormKind {
  String get label => switch (this) {
    CreatorFormKind.task => 'Task',
    CreatorFormKind.goal => 'Goal',
    CreatorFormKind.habit => 'Daily Rhythm',
    CreatorFormKind.note => 'Note',
  };
}

final creatorNavigationIntentProvider =
    NotifierProvider<CreatorNavigationIntentNotifier, CreatorFormKind>(
      CreatorNavigationIntentNotifier.new,
    );

class CreatorNavigationIntentNotifier extends Notifier<CreatorFormKind> {
  @override
  CreatorFormKind build() => CreatorFormKind.task;

  void open(CreatorFormKind type) => state = type;
}
