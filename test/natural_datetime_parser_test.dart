import 'package:flutter_test/flutter_test.dart';

import 'package:todo_app/utils/natural_datetime_parser.dart';

void main() {
  final now = DateTime(2026, 9, 7, 10, 30);

  group('natural dates', () {
    test('parses English month names and relative dates', () {
      for (final text in [
        'Sep 5',
        'Sep. 5',
        'Sept 5',
        'Sept. 5',
        'September 5',
      ]) {
        expect(
          NaturalDateTimeParser.parseDate(
            text: text,
            now: now,
            languageCode: 'en',
          ),
          DateTime(2027, 9, 5),
        );
      }
      expect(
        NaturalDateTimeParser.parseDate(
          text: 'Sep 5, 2026',
          now: now,
          languageCode: 'en',
        ),
        DateTime(2026, 9, 5),
      );
      expect(
        NaturalDateTimeParser.parseDate(
          text: 'tomorrow',
          now: now,
          languageCode: 'en',
        ),
        DateTime(2026, 9, 8),
      );
    });

    test('parses German month names and numeric dates', () {
      for (final text in [
        '5. Sep',
        '5. Sep.',
        '5. Sept',
        '5. Sept.',
        '5. September',
      ]) {
        expect(
          NaturalDateTimeParser.parseDate(
            text: text,
            now: now,
            languageCode: 'de',
          ),
          DateTime(2027, 9, 5),
        );
      }
      expect(
        NaturalDateTimeParser.parseDate(
          text: '05.09.',
          now: now,
          languageCode: 'de',
        ),
        DateTime(2027, 9, 5),
      );
      expect(
        NaturalDateTimeParser.parseDate(
          text: '05.09.2026',
          now: now,
          languageCode: 'de',
        ),
        DateTime(2026, 9, 5),
      );
      expect(
        NaturalDateTimeParser.parseDate(
          text: 'morgen',
          now: now,
          languageCode: 'de',
        ),
        DateTime(2026, 9, 8),
      );
      expect(
        NaturalDateTimeParser.parseDate(
          text: 'Montag',
          now: now,
          languageCode: 'de',
        ),
        DateTime(2026, 9, 14),
      );
      expect(
        NaturalDateTimeParser.parseDate(
          text: 'nächsten Dienstag',
          now: now,
          languageCode: 'de',
        ),
        DateTime(2026, 9, 8),
      );
      expect(
        NaturalDateTimeParser.parseDate(
          text: 'übermorgen',
          now: now,
          languageCode: 'de',
        ),
        DateTime(2026, 9, 9),
      );
      expect(
        NaturalDateTimeParser.parseDate(
          text: 'in 2 Tagen',
          now: now,
          languageCode: 'de',
        ),
        DateTime(2026, 9, 9),
      );
    });

    test('parses English weekdays and relative dates', () {
      expect(
        NaturalDateTimeParser.parseDate(
          text: 'Monday',
          now: now,
          languageCode: 'en',
        ),
        DateTime(2026, 9, 14),
      );
      expect(
        NaturalDateTimeParser.parseDate(
          text: 'next Tuesday',
          now: now,
          languageCode: 'en',
        ),
        DateTime(2026, 9, 8),
      );
      expect(
        NaturalDateTimeParser.parseDate(
          text: 'day after tomorrow',
          now: now,
          languageCode: 'en',
        ),
        DateTime(2026, 9, 9),
      );
      expect(
        NaturalDateTimeParser.parseDate(
          text: 'next week',
          now: now,
          languageCode: 'en',
        ),
        DateTime(2026, 9, 14),
      );
    });

    test('rejects invalid dates and ambiguous numeric expressions', () {
      for (final text in [
        'February 30',
        'Sep 5 20260',
        '32.09.',
        '5/6',
        '06/05',
        '5-6',
      ]) {
        expect(
          NaturalDateTimeParser.parseDate(
            text: text,
            now: now,
            languageCode: text.contains('.') ? 'de' : 'en',
          ),
          isNull,
        );
      }
      expect(
        NaturalDateTimeParser.parseDate(
          text: '5. September 20260',
          now: now,
          languageCode: 'de',
        ),
        isNull,
      );
    });
  });

  group('natural times', () {
    test('parses English and German time forms', () {
      final english = <String, int>{
        '6 PM': 18 * 60,
        '6PM': 18 * 60,
        '6:30 PM': 18 * 60 + 30,
        '6:30PM': 18 * 60 + 30,
        '9 AM': 9 * 60,
        '9:15 AM': 9 * 60 + 15,
        '12 AM': 0,
        '12 PM': 12 * 60,
        '18:00': 18 * 60,
        '08:15': 8 * 60 + 15,
      };
      for (final entry in english.entries) {
        expect(
          NaturalDateTimeParser.parseTime(text: entry.key, languageCode: 'en'),
          entry.value,
        );
      }

      final german = <String, int>{
        '18 Uhr': 18 * 60,
        '18:30 Uhr': 18 * 60 + 30,
        '18.30 Uhr': 18 * 60 + 30,
        'morgens': 9 * 60,
        'mittags': 12 * 60,
        'abends': 18 * 60,
      };
      for (final entry in german.entries) {
        expect(
          NaturalDateTimeParser.parseTime(text: entry.key, languageCode: 'de'),
          entry.value,
        );
      }
      final timeOfDayEnglish = <String, int>{
        'morning': 9 * 60,
        'noon': 12 * 60,
        'evening': 18 * 60,
      };
      for (final entry in timeOfDayEnglish.entries) {
        expect(
          NaturalDateTimeParser.parseTime(text: entry.key, languageCode: 'en'),
          entry.value,
        );
      }
      expect(
        NaturalDateTimeParser.parseTime(
          text: 'morning',
          languageCode: 'en',
          morningReminderMinutes: 8 * 60,
        ),
        8 * 60,
      );
    });

    test('rejects standalone and malformed times', () {
      for (final text in [
        'at 5',
        '25:90',
        '13 PM',
        '12:60 PM',
        '25:09 PM',
        '13:09 PM',
        'abc18:00xyz',
        '18:30:45',
      ]) {
        expect(
          NaturalDateTimeParser.parseTime(text: text, languageCode: 'en'),
          isNull,
        );
      }
      for (final text in ['25:09 Uhr', 'abc18:00xyz', '18:30:45']) {
        expect(
          NaturalDateTimeParser.parseTime(text: text, languageCode: 'de'),
          isNull,
        );
      }
    });
  });

  test('uses title before description independently for each field', () {
    final result = NaturalDateTimeParser.parse(
      title: 'Sep 5 at 18:00',
      description: 'Sep 6 at 19:00',
      now: now,
      languageCode: 'en',
    );
    expect(result.date, DateTime(2027, 9, 5));
    expect(result.minutes, 18 * 60);

    final dateOnly = NaturalDateTimeParser.parse(
      title: 'Review',
      description: 'tomorrow',
      now: now,
      languageCode: 'en',
    );
    expect(dateOnly.date, DateTime(2026, 9, 8));
    expect(dateOnly.minutes, isNull);
  });

  test('returns exact source ranges and merges a date-time connector', () {
    const text = 'Dinner with Lea tomorrow at 7 PM';
    final result = NaturalDateTimeParser.parse(
      title: text,
      description: '',
      now: now,
      languageCode: 'en',
    );

    expect(
      text.substring(
        result.dateSourceRange!.start,
        result.dateSourceRange!.end,
      ),
      'tomorrow',
    );
    expect(
      text.substring(
        result.timeSourceRange!.start,
        result.timeSourceRange!.end,
      ),
      '7 PM',
    );
    final merged = NaturalDateTimeParser.mergeSourceRanges(
      text: text,
      ranges: [result.dateSourceRange!, result.timeSourceRange!],
    );
    expect(merged, hasLength(1));
    expect(
      text.substring(merged.single.start, merged.single.end),
      'tomorrow at 7 PM',
    );
  });

  test('keeps separated date and time ranges separate', () {
    const text = 'Call Max Sep 15 before the trip, then 18:00';
    final result = NaturalDateTimeParser.parse(
      title: text,
      description: '',
      now: now,
      languageCode: 'en',
    );
    final ranges = NaturalDateTimeParser.mergeSourceRanges(
      text: text,
      ranges: [result.dateSourceRange!, result.timeSourceRange!],
    );

    expect(ranges, hasLength(2));
    expect(ranges.map((range) => text.substring(range.start, range.end)), [
      'Sep 15',
      '18:00',
    ]);
  });

  test('source ranges retain their input and UTF-16 offsets', () {
    const title = '電話 tomorrow';
    const description = 'Notizen um 10:30 Uhr';
    final result = NaturalDateTimeParser.parse(
      title: title,
      description: description,
      now: now,
      languageCode: 'de',
    );

    expect(result.dateSourceRange, isNull);
    expect(result.timeSourceRange!.source, NaturalDateTimeSource.description);
    expect(
      description.substring(
        result.timeSourceRange!.start,
        result.timeSourceRange!.end,
      ),
      '10:30 Uhr',
    );

    final english = NaturalDateTimeParser.parse(
      title: title,
      description: '',
      now: now,
      languageCode: 'en',
    );
    expect(english.dateSourceRange!.source, NaturalDateTimeSource.title);
    expect(
      title.substring(
        english.dateSourceRange!.start,
        english.dateSourceRange!.end,
      ),
      'tomorrow',
    );
  });

  test('invalid input has no values or source ranges', () {
    final result = NaturalDateTimeParser.parse(
      title: 'Call sometime after lunch',
      description: 'No fixed plan',
      now: now,
      languageCode: 'en',
    );

    expect(result.date, isNull);
    expect(result.minutes, isNull);
    expect(result.dateSourceRange, isNull);
    expect(result.timeSourceRange, isNull);
  });
}
