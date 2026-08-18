import 'package:fantastic_guacamole/state/providers/creator_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Creator receipt round-trips as a versioned typed record', () {
    final CreatorCreationReceipt receipt = CreatorCreationReceipt(
      kind: CreatorSavedKind.note,
      title: 'Decision context',
      createdAt: DateTime.utc(2026, 8, 16, 12),
      whyItMatters: 'It preserves evidence for later decisions.',
      nextAction: 'Review the new context in Smart Planner.',
    );

    final CreatorCreationReceipt? restored = CreatorCreationReceipt.fromJson(
      receipt.toJson(),
    );

    expect(restored, isNotNull);
    expect(restored!.kind, CreatorSavedKind.note);
    expect(restored.title, receipt.title);
    expect(restored.createdAt, receipt.createdAt);
    expect(restored.whyItMatters, receipt.whyItMatters);
    expect(restored.nextAction, receipt.nextAction);
    expect(receipt.toJson()['version'], 1);
  });

  test('Creator receipt rejects malformed continuity data', () {
    expect(CreatorCreationReceipt.fromJson(null), isNull);
    expect(
      CreatorCreationReceipt.fromJson(<String, dynamic>{
        'kind': 'task',
        'title': '',
        'createdAt': 'not-a-date',
      }),
      isNull,
    );
  });
}
