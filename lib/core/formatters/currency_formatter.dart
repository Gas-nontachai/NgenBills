import 'package:intl/intl.dart';

abstract final class Money {
  // Keep all parsing and arithmetic in integer satang. Bound inputs below
  // SQLite's signed integer limit and JavaScript's exact integer limit.
  static const maxMinor = 99999999999999;
  static int? parse(String input) {
    final value = input.trim();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) return null;
    final parts = value.split('.');
    final whole = int.tryParse(parts[0]);
    if (whole == null || whole > maxMinor ~/ 100) return null;
    final result =
        whole * 100 +
        (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
    return result <= maxMinor ? result : null;
  }

  static String format(int minor, {bool decimals = false}) {
    final whole = NumberFormat('#,##0', 'th').format(minor ~/ 100);
    final cents = minor % 100;
    return '฿$whole${decimals || cents != 0 ? '.${cents.toString().padLeft(2, '0')}' : ''}';
  }

  static String input(int minor) =>
      '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';
  static String? validate(String? input, {int? remaining}) {
    final value = parse(input ?? '');
    if (value == null) {
      return 'กรอกจำนวนเงินให้ถูกต้อง (ทศนิยมไม่เกิน 2 ตำแหน่ง)';
    }
    if (value <= 0) return 'จำนวนเงินต้องมากกว่า 0 บาท';
    if (remaining != null && value > remaining) {
      return 'จำนวนเงินเกินยอดคงเหลือ ${format(remaining)}';
    }
    return null;
  }
}
