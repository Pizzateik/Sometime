class NaturalDateTimeSuggestion {
  const NaturalDateTimeSuggestion({this.date, this.minutes});

  final DateTime? date;
  final int? minutes;
}

class NaturalDateTimeParser {
  const NaturalDateTimeParser._();

  static final _englishRelative = RegExp(
    r'(?<![A-Za-zÄÖÜäöüß0-9])'
    r'(today|tomorrow|day[ \t]+after[ \t]+tomorrow|'
    r'in[ \t]+(?:2|3)[ \t]+days|next[ \t]+week)'
    r'(?![A-Za-zÄÖÜäöüß0-9])',
    caseSensitive: false,
  );
  static final _germanRelative = RegExp(
    r'(?<![A-Za-zÄÖÜäöüß0-9])'
    r'(heute|morgen|übermorgen|in[ \t]+(?:2|3)[ \t]+tagen|nächste[ \t]+woche)'
    r'(?![A-Za-zÄÖÜäöüß0-9])',
    caseSensitive: false,
  );
  static final _englishWeekday = RegExp(
    r'(?<![A-Za-zÄÖÜäöüß0-9])'
    r'(?:(?:on|next)[ \t]+)?'
    r'(monday|tuesday|wednesday|thursday|friday|saturday|sunday)'
    r'(?![A-Za-zÄÖÜäöüß0-9])',
    caseSensitive: false,
  );
  static final _germanWeekday = RegExp(
    r'(?<![A-Za-zÄÖÜäöüß0-9])'
    r'(?:(?:am|nächsten)[ \t]+)?'
    r'(montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonntag)'
    r'(?![A-Za-zÄÖÜäöüß0-9])',
    caseSensitive: false,
  );
  static final _englishNamedDate = RegExp(
    r'(?<![A-Za-zÄÖÜäöüß0-9])([A-Za-zÄÖÜäöüß]+)\.?[ \t]+'
    r'(0?[1-9]|[12][0-9]|3[01])(?:(?:[ \t]*,[ \t]*|[ \t]+)'
    r'([0-9]{4}))?(?![A-Za-zÄÖÜäöüß0-9])'
    r'(?![ \t]*(?:,[ \t]*|[ \t]+)[0-9])',
    caseSensitive: false,
  );
  static final _germanNamedDate = RegExp(
    r'(?<![A-Za-zÄÖÜäöüß0-9])(0?[1-9]|[12][0-9]|3[01])\.[ \t]+'
    r'([A-Za-zÄÖÜäöüß]+)\.?(?:[ \t]+([0-9]{4}))?'
    r'(?![A-Za-zÄÖÜäöüß0-9])'
    r'(?![ \t]+[0-9])',
    caseSensitive: false,
  );
  static final _germanNumericDate = RegExp(
    r'(?<![A-Za-zÄÖÜäöüß0-9])([0-3]?[0-9])\.([0-1]?[0-9])'
    r'(?:\.([0-9]{4})|\.)(?![A-Za-zÄÖÜäöüß0-9])',
    caseSensitive: false,
  );
  static final _clockTime = RegExp(
    r'(?<![A-Za-zÄÖÜäöüß0-9:])([0-9]{1,2}):([0-9]{2})'
    r'(?![A-Za-zÄÖÜäöüß0-9:])',
  );
  static final _englishAmPmTime = RegExp(
    r'(?<![A-Za-zÄÖÜäöüß0-9:.])([0-9]{1,2})(?::([0-9]{2}))?'
    r'[ \t]*(am|pm)(?![A-Za-zÄÖÜäöüß0-9])',
    caseSensitive: false,
  );
  static final _germanUhrTime = RegExp(
    r'(?<![A-Za-zÄÖÜäöüß0-9:.])([0-9]{1,2})'
    r'(?:(?::([0-9]{2})|\.([0-9]{2})))?[ \t]*uhr'
    r'(?![A-Za-zÄÖÜäöüß0-9])',
    caseSensitive: false,
  );
  static final _englishTimeOfDay = RegExp(
    r'(?<![A-Za-zÄÖÜäöüß0-9])(morning|noon|evening)'
    r'(?![A-Za-zÄÖÜäöüß0-9])',
    caseSensitive: false,
  );
  static final _germanTimeOfDay = RegExp(
    r'(?<![A-Za-zÄÖÜäöüß0-9])(morgens|mittags|abends)'
    r'(?![A-Za-zÄÖÜäöüß0-9])',
    caseSensitive: false,
  );
  static final _whitespaceRegex = RegExp(r'\s+');
  static final _uhrSuffix = RegExp(r'^\s*uhr\b', caseSensitive: false);
  static final _amPmSuffix = RegExp(r'^\s*(?:am|pm)\b', caseSensitive: false);

  static const _englishMonths = <String, int>{
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };
  static const _germanMonths = <String, int>{
    'jan': 1,
    'januar': 1,
    'feb': 2,
    'februar': 2,
    'mär': 3,
    'märz': 3,
    'mae': 3,
    'maerz': 3,
    'apr': 4,
    'april': 4,
    'mai': 5,
    'jun': 6,
    'juni': 6,
    'jul': 7,
    'juli': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'okt': 10,
    'oktober': 10,
    'nov': 11,
    'november': 11,
    'dez': 12,
    'dezember': 12,
  };

  static NaturalDateTimeSuggestion parse({
    required String title,
    required String description,
    required DateTime now,
    required String languageCode,
    int morningReminderMinutes = 9 * 60,
  }) {
    try {
      final german = languageCode.toLowerCase().startsWith('de');
      return NaturalDateTimeSuggestion(
        date:
            _firstDate(title, now, german) ??
            _firstDate(description, now, german),
        minutes:
            _firstTime(title, german, morningReminderMinutes) ??
            _firstTime(description, german, morningReminderMinutes),
      );
    } catch (_) {
      return const NaturalDateTimeSuggestion();
    }
  }

  static DateTime? parseDate({
    required String text,
    required DateTime now,
    required String languageCode,
  }) {
    try {
      return _firstDate(text, now, languageCode.toLowerCase().startsWith('de'));
    } catch (_) {
      return null;
    }
  }

  static int? parseTime({
    required String text,
    required String languageCode,
    int morningReminderMinutes = 9 * 60,
  }) {
    try {
      return _firstTime(
        text,
        languageCode.toLowerCase().startsWith('de'),
        morningReminderMinutes,
      );
    } catch (_) {
      return null;
    }
  }

  static DateTime? _firstDate(String text, DateTime now, bool german) {
    final candidates = <_IndexedValue<DateTime>>[];
    final relative = (german ? _germanRelative : _englishRelative).allMatches(
      text,
    );
    for (final match in relative) {
      final expression = match
          .group(0)!
          .toLowerCase()
          .replaceAll(_whitespaceRegex, ' ')
          .trim();
      final offset = switch (expression) {
        'today' || 'heute' => 0,
        'tomorrow' || 'morgen' => 1,
        'day after tomorrow' || 'übermorgen' => 2,
        'in 2 days' || 'in 2 tagen' => 2,
        'in 3 days' || 'in 3 tagen' => 3,
        'next week' || 'nächste woche' => 7,
        _ => null,
      };
      if (offset != null) {
        candidates.add(
          _IndexedValue(
            match.start,
            _calendarDate(now.year, now.month, now.day + offset),
          ),
        );
      }
    }

    final weekdays = (german ? _germanWeekday : _englishWeekday).allMatches(
      text,
    );
    for (final match in weekdays) {
      final weekday = (german
          ? _germanWeekdays
          : _englishWeekdays)[match.group(1)!.toLowerCase()];
      if (weekday == null) continue;
      candidates.add(_IndexedValue(match.start, _nextWeekday(now, weekday)));
    }

    final named = (german ? _germanNamedDate : _englishNamedDate).allMatches(
      text,
    );
    for (final match in named) {
      final month = german
          ? _germanMonths[match.group(2)!.toLowerCase()]
          : _englishMonths[match.group(1)!.toLowerCase()];
      final day = int.tryParse(german ? match.group(1)! : match.group(2)!);
      final yearText = german ? match.group(3) : match.group(3);
      final year = yearText == null ? null : int.tryParse(yearText);
      final date = month == null || day == null
          ? null
          : _resolveDate(month, day, year, now);
      if (date != null) candidates.add(_IndexedValue(match.start, date));
    }

    if (german) {
      for (final match in _germanNumericDate.allMatches(text)) {
        final day = int.tryParse(match.group(1)!);
        final month = int.tryParse(match.group(2)!);
        final yearText = match.group(3);
        final year = yearText == null ? null : int.tryParse(yearText);
        final date = day == null || month == null
            ? null
            : _resolveDate(month, day, year, now);
        if (date != null) candidates.add(_IndexedValue(match.start, date));
      }
    }

    candidates.sort((a, b) => a.index.compareTo(b.index));
    return candidates.isEmpty ? null : candidates.first.value;
  }

  static int? _firstTime(String text, bool german, int morningReminderMinutes) {
    final candidates = <_IndexedValue<int>>[];
    for (final match in _clockTime.allMatches(text)) {
      if (_hasSuffix(text, match.end, german ? 'uhr' : 'am|pm')) continue;
      final hour = int.tryParse(match.group(1)!);
      final minute = int.tryParse(match.group(2)!);
      if (hour == null || minute == null || hour > 23 || minute > 59) {
        continue;
      }
      candidates.add(_IndexedValue(match.start, hour * 60 + minute));
    }

    if (german) {
      for (final match in _germanUhrTime.allMatches(text)) {
        final hour = int.tryParse(match.group(1)!);
        final minute = int.tryParse(match.group(2) ?? match.group(3) ?? '0');
        if (hour == null || minute == null || hour > 23 || minute > 59) {
          continue;
        }
        candidates.add(_IndexedValue(match.start, hour * 60 + minute));
      }
    } else {
      for (final match in _englishAmPmTime.allMatches(text)) {
        final hour = int.tryParse(match.group(1)!);
        final minute = int.tryParse(match.group(2) ?? '0');
        if (hour == null ||
            minute == null ||
            hour < 1 ||
            hour > 12 ||
            minute > 59) {
          continue;
        }
        final suffix = match.group(3)!.toLowerCase();
        final normalizedHour = hour == 12
            ? (suffix == 'am' ? 0 : 12)
            : suffix == 'am'
            ? hour
            : hour + 12;
        candidates.add(
          _IndexedValue(match.start, normalizedHour * 60 + minute),
        );
      }
    }

    final timeOfDay = (german ? _germanTimeOfDay : _englishTimeOfDay)
        .allMatches(text);
    for (final match in timeOfDay) {
      final value = match.group(1)!.toLowerCase();
      final minutes = switch (value) {
        'morning' || 'morgens' => _validMorningMinutes(morningReminderMinutes),
        'noon' || 'mittags' => 12 * 60,
        'evening' || 'abends' => 18 * 60,
        _ => null,
      };
      if (minutes != null) {
        candidates.add(_IndexedValue(match.start, minutes));
      }
    }

    candidates.sort((a, b) => a.index.compareTo(b.index));
    return candidates.isEmpty ? null : candidates.first.value;
  }

  static bool _hasSuffix(String text, int end, String suffix) {
    final rest = text.substring(end);
    final regex = suffix == 'uhr' ? _uhrSuffix : _amPmSuffix;
    return regex.hasMatch(rest);
  }

  static DateTime? _resolveDate(int month, int day, int? year, DateTime now) {
    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        year != null && (year < 1900 || year > 2200)) {
      return null;
    }
    final today = _calendarDate(now.year, now.month, now.day);
    if (year != null) return _validDate(year, month, day);
    for (var offset = 0; offset <= 8; offset++) {
      final candidateYear = now.year + offset;
      final candidate = _validDate(candidateYear, month, day);
      if (candidate != null && !candidate.isBefore(today)) {
        return candidate;
      }
    }
    return null;
  }

  static DateTime? _validDate(int year, int month, int day) {
    final date = DateTime(year, month, day);
    return date.year == year &&
            date.month == month &&
            date.day == day &&
            year >= 1900 &&
            year <= 2200
        ? _calendarDate(year, month, day)
        : null;
  }

  static DateTime _calendarDate(int year, int month, int day) =>
      DateTime(year, month, day);

  static int _validMorningMinutes(int minutes) =>
      minutes >= 0 && minutes < 24 * 60 ? minutes : 9 * 60;

  static DateTime _nextWeekday(DateTime now, int weekday) {
    var offset = (weekday - now.weekday) % DateTime.daysPerWeek;
    if (offset == 0) offset = DateTime.daysPerWeek;
    return _calendarDate(now.year, now.month, now.day + offset);
  }

  static const _englishWeekdays = <String, int>{
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  static const _germanWeekdays = <String, int>{
    'montag': DateTime.monday,
    'dienstag': DateTime.tuesday,
    'mittwoch': DateTime.wednesday,
    'donnerstag': DateTime.thursday,
    'freitag': DateTime.friday,
    'samstag': DateTime.saturday,
    'sonntag': DateTime.sunday,
  };
}

class _IndexedValue<T> {
  const _IndexedValue(this.index, this.value);

  final int index;
  final T value;
}
