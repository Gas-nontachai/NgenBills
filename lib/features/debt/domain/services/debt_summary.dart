import '../entities/debt.dart';
import '../entities/borrowing.dart';
import '../../../payment/domain/entities/payment.dart';

class DebtSummary {
  DebtSummary(this.debt, this.payments, [this.borrowings = const []]);
  final List<Borrowing> borrowings;
  int get totalBorrowed => borrowings.fold(0, (sum, b) => sum + b.amountMinor);
  int get totalDebt => debt.initialAmountMinor + totalBorrowed;
  String get progressLabel =>
      (progress * 100).toStringAsFixed(1).replaceFirst(RegExp(r"\.0$"), "");
  List<DebtHistoryEntry> get history =>
      [
        ...payments.map((p) => DebtHistoryEntry(payment: p)),
        ...borrowings.map((b) => DebtHistoryEntry(borrowing: b)),
      ]..sort((a, b) {
        final date = b.date.compareTo(a.date);
        if (date != 0) return date;
        final created = b.createdAt.compareTo(a.createdAt);
        return created != 0 ? created : b.id.compareTo(a.id);
      });
  final Debt debt;
  final List<Payment> payments;
  int get totalPaid => payments.fold(0, (sum, p) => sum + p.amountMinor);
  int get remaining => totalDebt - totalPaid;
  double get progress => (totalPaid / totalDebt).clamp(0.0, 1.0);
  bool get isPaid => remaining == 0;
}

class DebtHistoryEntry {
  const DebtHistoryEntry({this.payment, this.borrowing})
    : assert((payment == null) != (borrowing == null));
  final Payment? payment;
  final Borrowing? borrowing;
  String get id => payment?.id ?? borrowing!.id;
  DateTime get date => payment?.date ?? borrowing!.date;
  DateTime get createdAt => payment?.createdAt ?? borrowing!.createdAt;
}
