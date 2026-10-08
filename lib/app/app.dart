import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import '../features/debt/presentation/providers/debt_providers.dart';
import '../features/reminders/presentation/reminder_providers.dart';
import 'theme/app_theme.dart';

class NgenBillsApp extends ConsumerStatefulWidget {
  const NgenBillsApp({super.key});
  @override
  ConsumerState<NgenBillsApp> createState() => _NgenBillsAppState();
}

class _NgenBillsAppState extends ConsumerState<NgenBillsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(reminderControllerProvider.notifier).refresh());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(reminderControllerProvider.notifier).refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(debtSummaryProvider, (previous, next) {
      // A committed payment still needs reconciliation if the Home read fails.
      // The controller performs its own fresh read and clears stale reminders
      // when the database cannot be read safely.
      if (!next.isLoading) {
        unawaited(ref.read(reminderControllerProvider.notifier).refresh());
      }
    });
    return MaterialApp.router(
      title: 'เงินบิล - NgenBills',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      locale: const Locale('th'),
      supportedLocales: const [Locale('th')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
