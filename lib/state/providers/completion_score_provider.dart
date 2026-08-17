import 'package:fantastic_guacamole/state/models/completion_score_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final completionScoreProvider =
    NotifierProvider<CompletionScoreNotifier, CompletionScoreView?>(
      CompletionScoreNotifier.new,
    );

class CompletionScoreNotifier extends Notifier<CompletionScoreView?> {
  @override
  CompletionScoreView? build() => null;

  void set(CompletionScoreView? value) => state = value;
}
