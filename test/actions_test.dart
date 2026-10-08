import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngenbills/features/debt/presentation/providers/debt_providers.dart';

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
}
