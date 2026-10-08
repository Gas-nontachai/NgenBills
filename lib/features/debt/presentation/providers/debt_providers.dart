import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../data/repositories/debt_repository.dart';
import '../../domain/services/debt_summary.dart';
import '../../../payment/data/repositories/payment_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
final debtRepositoryProvider = Provider(
  (ref) => DebtRepository(ref.watch(databaseProvider)),
);
final paymentRepositoryProvider = Provider(
  (ref) => PaymentRepository(ref.watch(databaseProvider)),
);
final debtSummaryProvider = FutureProvider<DebtSummary?>(
  (ref) => ref.watch(debtRepositoryProvider).load(),
);
final paymentActionProvider = NotifierProvider<PaymentAction, bool>(
  PaymentAction.new,
);

class PaymentAction extends Notifier<bool> {
  @override
  bool build() => false;
  Future<bool> run(Future<void> Function() action) async {
    if (state) return false;
    state = true;
    try {
      await action();
      ref.invalidate(debtSummaryProvider);
      // Refresh separately: a read failure must never be reported as a failed
      // write after the transaction has already committed.
      return true;
    } finally {
      state = false;
    }
  }
}
