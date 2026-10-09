import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngenbills/features/debt/presentation/providers/debt_providers.dart';
import 'package:ngenbills/features/debt/domain/entities/debt.dart';

void main() {
  test(
    'Repeated submissions share a lock and cannot duplicate writes',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final action = container.read(paymentActionProvider.notifier);
      final completion = Completer<void>();
      var writes = 0;
      final first = action.run(() async {
        writes++;
        await completion.future;
      });
      expect(container.read(paymentActionProvider), true);
      expect(
        await action.run(() async {
          writes++;
        }),
        false,
      );
      expect(writes, 1);
      completion.complete();
      expect(await first, true);
      expect(container.read(paymentActionProvider), false);
    },
  );
  test('Write failures release the submission lock for retry', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final action = container.read(paymentActionProvider.notifier);
    await expectLater(
      action.run(() async => throw StateError('failed')),
      throwsStateError,
    );
    expect(container.read(paymentActionProvider), false);
    expect(await action.run(() async {}), true);
  });
  test(
    'A committed write releases the lock while refreshed reads are pending',
    () async {
      final pending = Completer<List<Debt>>();
      final container = ProviderContainer(
        overrides: [accountsProvider.overrideWith((ref) => pending.future)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(accountsProvider, (_, _) {});
      addTearDown(subscription.close);
      expect(
        await container.read(paymentActionProvider.notifier).run(() async {}),
        true,
      );
      expect(container.read(paymentActionProvider), false);
      expect(container.read(accountsProvider).isLoading, true);
      pending.complete([]);
    },
  );
}
