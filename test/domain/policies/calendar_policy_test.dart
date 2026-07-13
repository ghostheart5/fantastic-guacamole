import 'package:fantastic_guacamole/domain/entities/calendar_entry_entity.dart';
import 'package:fantastic_guacamole/domain/policies/calendar_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarPolicy', () {
    test(
      'isValidEntry returns true when title is non-empty and end is after start',
      () {
        final entry = CalendarEntryEntity(
          id: 'c1',
          title: 'Standup',
          start: DateTime.utc(2026, 7, 5, 9),
          end: DateTime.utc(2026, 7, 5, 9, 30),
        );

        expect(CalendarPolicy.isValidEntry(entry), isTrue);
      },
    );

    test('isValidEntry returns false for blank title', () {
      final entry = CalendarEntryEntity(
        id: 'c2',
        title: ' ',
        start: DateTime.utc(2026, 7, 5, 9),
        end: DateTime.utc(2026, 7, 5, 10),
      );

      expect(CalendarPolicy.isValidEntry(entry), isFalse);
    });

    test('isValidEntry returns false when end is not after start', () {
      final same = CalendarEntryEntity(
        id: 'c3',
        title: 'Zero length',
        start: DateTime.utc(2026, 7, 5, 10),
        end: DateTime.utc(2026, 7, 5, 10),
      );
      final reversed = CalendarEntryEntity(
        id: 'c4',
        title: 'Backwards',
        start: DateTime.utc(2026, 7, 5, 10),
        end: DateTime.utc(2026, 7, 5, 9),
      );

      expect(CalendarPolicy.isValidEntry(same), isFalse);
      expect(CalendarPolicy.isValidEntry(reversed), isFalse);
    });

    test('rejects overlapping time blocks', () {
      final existing = CalendarEntryEntity(
        id: 'c5',
        title: 'Deep Work',
        start: DateTime.utc(2026, 7, 5, 10),
        end: DateTime.utc(2026, 7, 5, 11),
      );
      final overlapping = CalendarEntryEntity(
        id: 'c6',
        title: 'Overlap',
        start: DateTime.utc(2026, 7, 5, 10, 30),
        end: DateTime.utc(2026, 7, 5, 11, 30),
      );

      expect(
        CalendarPolicy.canPlaceEntry(
          candidate: overlapping,
          dayEntries: <CalendarEntryEntity>[existing],
        ),
        isFalse,
      );
    });

    test('accepts adjacent blocks', () {
      final existing = CalendarEntryEntity(
        id: 'c7',
        title: 'Block A',
        start: DateTime.utc(2026, 7, 5, 9),
        end: DateTime.utc(2026, 7, 5, 10),
      );
      final adjacent = CalendarEntryEntity(
        id: 'c8',
        title: 'Block B',
        start: DateTime.utc(2026, 7, 5, 10),
        end: DateTime.utc(2026, 7, 5, 11),
      );

      expect(
        CalendarPolicy.canPlaceEntry(
          candidate: adjacent,
          dayEntries: <CalendarEntryEntity>[existing],
        ),
        isTrue,
      );
    });

    test('handles empty day', () {
      final candidate = CalendarEntryEntity(
        id: 'c9',
        title: 'Only entry',
        start: DateTime.utc(2026, 7, 5, 13),
        end: DateTime.utc(2026, 7, 5, 14),
      );

      expect(
        CalendarPolicy.canPlaceEntry(
          candidate: candidate,
          dayEntries: const <CalendarEntryEntity>[],
        ),
        isTrue,
      );
    });

    test('handles invalid end-before-start candidate', () {
      final invalid = CalendarEntryEntity(
        id: 'c10',
        title: 'Invalid',
        start: DateTime.utc(2026, 7, 5, 15),
        end: DateTime.utc(2026, 7, 5, 14),
      );

      expect(
        CalendarPolicy.canPlaceEntry(
          candidate: invalid,
          dayEntries: const <CalendarEntryEntity>[],
        ),
        isFalse,
      );
    });

    test('recurring entries support flag is explicit', () {
      expect(CalendarPolicy.supportsRecurringEntries, isFalse);
    });
  });
}
