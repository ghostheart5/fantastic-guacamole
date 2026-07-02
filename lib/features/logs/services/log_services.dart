import 'package:fantastic_guacamole/features/logs/logic/log_formatter.dart';

class LogServices {
  const LogServices({this.formatter = const LogFormatter()});

  final LogFormatter formatter;

  List<String> prepareEntries(List<String> entries) {
    return formatter.normalizeAll(entries);
  }
}
