import '../entities/debt.dart';
import '../../../payment/domain/entities/payment.dart';

class DebtSummary {
  DebtSummary(this.debt, this.payments);
  final Debt debt;
  final List<Payment> payments;
  int get totalPaid => payments.fold(0, (sum, p) => sum + p.amountMinor);
  int get remaining => debt.initialAmountMinor - totalPaid;
  double get progress => (totalPaid / debt.initialAmountMinor).clamp(0.0, 1.0);
  bool get isPaid => remaining == 0;
}
