import 'package:flutter_test/flutter_test.dart';
import 'package:ngenbills/core/formatters/currency_formatter.dart';
import 'package:ngenbills/features/debt/domain/entities/debt.dart';
import 'package:ngenbills/features/debt/domain/services/debt_summary.dart';
import 'package:ngenbills/features/payment/domain/entities/payment.dart';

void main() {
  final date = DateTime(2026, 10, 8);
  final debt = Debt(
    id: 'debt',
    name: 'บัตรเครดิต',
    initialAmountMinor: 1000000,
    createdAt: date,
    updatedAt: date,
  );
  Payment payment(int amount) => Payment(
    id: '$amount',
    debtId: debt.id,
    amountMinor: amount,
    date: date,
    createdAt: date,
  );
  test('Satang conversion is exact, including fractions and leading zeros', () {
    expect(Money.parse('1500.50'), 150050);
    expect(Money.parse('0.01'), 1);
    expect(Money.parse('00100.1'), 10010);
    expect(Money.parse(' 100 '), 10000);
    expect(Money.format(150050), '฿1,500.50');
    expect(Money.input(1), '0.01');
  });
  test('Reject malformed, excessive precision and out-of-range amounts', () {
    for (final input in [
      '',
      '-1',
      '1.001',
      'NaN',
      '1e3',
      '1,000',
      '.',
      '1.',
      '9999999999999999999999',
    ]) {
      expect(Money.parse(input), isNull, reason: input);
    }
    expect(Money.validate('0'), isNotNull);
    expect(Money.validate('-10'), isNotNull);
    expect(Money.validate('100.01', remaining: 10000), isNotNull);
    expect(Money.validate('100', remaining: 10000), isNull);
  });
  test('Initial debt has zero paid and zero progress', () {
    final summary = DebtSummary(debt, []);
    expect(summary.totalPaid, 0);
    expect(summary.remaining, 1000000);
    expect(summary.progress, 0);
    expect(summary.isPaid, false);
  });
  test('Payment aggregation, remaining and progress use integer satang', () {
    final summary = DebtSummary(debt, [payment(100001), payment(199999)]);
    expect(summary.totalPaid, 300000);
    expect(summary.remaining, 700000);
    expect(summary.progress, .3);
  });
  test('Fully paid transition and deleting a payment restore progress', () {
    final payments = [payment(300000), payment(700000)];
    expect(DebtSummary(debt, payments).isPaid, true);
    expect(DebtSummary(debt, payments).progress, 1);
    payments.removeLast();
    expect(DebtSummary(debt, payments).isPaid, false);
    expect(DebtSummary(debt, payments).remaining, 700000);
  });
}
