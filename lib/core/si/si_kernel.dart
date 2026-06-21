class SIKernel {
  final List<String> memory = [];

  String process(String input) {
    final String raw = input.trim();
    final String sanitized = raw.replaceAll(RegExp(r'\\s+'), ' ');
    final String stamp = DateTime.now().toIso8601String();
    final String redacted = sanitized.toLowerCase().contains('classified')
        ? '[REDACTED]'
        : sanitized;

    memory.add('$stamp::$redacted');
    return '[SI-$stamp] $redacted';
  }
}
