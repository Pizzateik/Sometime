import 'dart:ui';

import 'package:intl/intl.dart';

class TodoDateFormatter {
  const TodoDateFormatter();

  static const englishWeekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const germanWeekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  static List<String> weekdaysFor(String languageCode) =>
      languageCode == 'de' ? germanWeekdays : englishWeekdays;

  String format(DateTime date, Locale locale) {
    return DateFormat('EEE dd', locale.toLanguageTag()).format(date);
  }
}
