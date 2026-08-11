import 'dart:math';

/// Fixed-seed data for Phase 10 property tests. This is test-only and has no
/// production, backend, clock, or network dependency.
class DeterministicGenerator {
  DeterministicGenerator(int seed) : _random = Random(seed);

  final Random _random;

  int between(int min, int max) => min + _random.nextInt(max - min + 1);

  bool get nextBool => _random.nextBool();

  DateTime utcInstant() => DateTime.utc(
    between(2020, 2035),
    between(1, 12),
    between(1, 28),
    between(0, 23),
    between(0, 59),
    between(0, 59),
  );

  String id(String prefix) => prefix + '-' + between(0, 1 << 30).toString();

  String unicodeText({required int length}) {
    const List<String> alphabet = <String>[
      'a',
      'Z',
      '0',
      ' ',
      'é',
      '漢',
      '🙂',
      '🧭',
      '—',
      'ß',
      '\n',
    ];
    return List<String>.generate(
      length,
      (_) => alphabet[_random.nextInt(alphabet.length)],
      growable: false,
    ).join();
  }
}

const List<int> phase10Seeds = <int>[
  260726,
  260801,
  260802,
  260803,
  704404,
];
