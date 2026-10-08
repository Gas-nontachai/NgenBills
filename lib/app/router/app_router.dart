import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/debt/presentation/screens/debt_home_screen.dart';
import '../../features/debt/presentation/screens/create_debt_screen.dart';
import '../../features/reminders/presentation/notification_settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const DebtHomeScreen()),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/create',
        builder: (context, state) => const CreateDebtScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
