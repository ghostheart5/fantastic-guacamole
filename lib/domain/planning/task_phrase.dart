/// Recognizes a single explicit relative date at the end of a task phrase.
({String title, DateTime dueDate})? parseTaskPhrase(
  String phrase, {
  required DateTime now,
  required bool spanish,
}) {
  final suffix = (spanish ? _spanishSuffix : _englishSuffix).firstMatch(
    phrase.trim(),
  );
  if (suffix == null) return null;

  final title = suffix.group(1)!.trim();
  if (_dateOrAlternative.hasMatch(title)) return null;

  final local = now.toLocal();
  final word = suffix.group(2)!.toLowerCase();
  final offset = word == 'today' || word == 'hoy' ? 0 : 1;
  return (
    title: title,
    dueDate: DateTime(local.year, local.month, local.day + offset),
  );
}

final _englishSuffix = RegExp(
  r'^(.+?)\s+(today|tomorrow)$',
  caseSensitive: false,
);
final _spanishSuffix = RegExp(r'^(.+?)\s+(hoy|mañana)$', caseSensitive: false);
final _dateOrAlternative = RegExp(
  r'\b(today|tomorrow|yesterday|tonight|hoy|ayer|lunes|martes|miércoles|jueves|viernes|sábado|domingo|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b|mañana|\d|\b(or|and|o|y|hasta|until|by|para|before|after|not|no|la|de)$',
  caseSensitive: false,
);
