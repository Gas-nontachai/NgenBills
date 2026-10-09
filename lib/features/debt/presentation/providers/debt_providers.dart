import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../data/repositories/debt_repository.dart';
import '../../data/repositories/borrowing_repository.dart';
import '../../domain/services/debt_summary.dart';
import '../../domain/entities/debt.dart';
import '../../../payment/data/repositories/payment_repository.dart';

final debtClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

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
final borrowingRepositoryProvider = Provider(
  (ref) => BorrowingRepository(ref.watch(databaseProvider)),
);
final accountsProvider = FutureProvider<List<Debt>>(
  (ref) => ref.watch(debtRepositoryProvider).list(),
);
final defaultDebtIdProvider = FutureProvider<String?>(
  (ref) => ref.watch(debtRepositoryProvider).defaultId(),
);
final selectedDebtIdProvider = NotifierProvider<SelectedDebtId, String?>(
  SelectedDebtId.new,
);

class SelectedDebtId extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) {
    state = id;
  }
}

final debtSummaryByIdProvider = FutureProvider.autoDispose
    .family<DebtSummary?, String>(
      (ref, id) => ref.watch(debtRepositoryProvider).load(id),
    );
final debtSummaryProvider = FutureProvider<DebtSummary?>((ref) async {
  final selected = ref.watch(selectedDebtIdProvider);
  final accountsFuture = ref.watch(accountsProvider.future);
  final defaultFuture = ref.watch(defaultDebtIdProvider.future);
  final accounts = await accountsFuture;
  final defaultId = await defaultFuture;
  if (!ref.mounted) return null;
  final id = accounts.any((a) => a.id == selected) ? selected : defaultId;
  if (id == null) return null;
  return ref.watch(debtSummaryByIdProvider(id).future);
});
final paymentActionProvider = NotifierProvider<PaymentAction, bool>(
  PaymentAction.new,
);

class PaymentAction extends Notifier<bool> {
  @override
  bool build() => false;
  Future<bool> run(
    Future<void> Function() action, {
    bool refreshDebt = true,
  }) async {
    if (state) return false;
    state = true;
    try {
      await action();
      if (refreshDebt) {
        ref.invalidate(accountsProvider);
        ref.invalidate(defaultDebtIdProvider);
        ref.invalidate(debtSummaryByIdProvider);
        ref.invalidate(debtSummaryProvider);
      }
      // Refresh separately: a read failure must never be reported as a failed
      // write after the transaction has already committed.
      return true;
    } finally {
      state = false;
    }
  }
}
