import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Build-time switch for the optional extra information in AI chat (habits,
/// recent results, goal progress). Off unless the build is made with
/// `--dart-define=CHRONOSPARK_AI_CHAT_EXTRA_SOURCES=true`. While it is off the
/// choices are not shown and a request never carries them, whatever a caller
/// asks for. Turn it on only after the server accepts these records and the
/// privacy text says AI chat can send them.
final aiChatExtraSourcesAvailableProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('CHRONOSPARK_AI_CHAT_EXTRA_SOURCES'),
);
