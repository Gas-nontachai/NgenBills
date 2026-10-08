import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class NgenBillsApp extends ConsumerWidget {
  const NgenBillsApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'เงินบิล - NgenBills',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    locale: const Locale('th'),
    supportedLocales: const [Locale('th')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: ref.watch(appRouterProvider),
  );
}
