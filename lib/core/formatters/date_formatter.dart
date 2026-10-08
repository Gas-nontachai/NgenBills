import 'package:clock/clock.dart';

abstract final class AppDates {
  static const months = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];
  static DateTime today() {
    final now = clock.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String storage(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static String format(DateTime date) =>
      '${date.day} ${months[date.month - 1]} ${date.year + 543}';
}
