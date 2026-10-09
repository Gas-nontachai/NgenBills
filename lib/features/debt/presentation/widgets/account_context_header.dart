import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/debt_providers.dart';
import 'account_avatar.dart';

class AccountContextHeader extends ConsumerWidget {
  const AccountContextHeader({super.key, required this.debtId, this.name});
  final String debtId;
  final String? name;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debt = ref
        .watch(accountsProvider)
        .value
        ?.where((a) => a.id == debtId)
        .firstOrNull;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AccountAvatar(
        iconKey: debt?.iconKey ?? 'wallet',
        colorKey: debt?.colorKey ?? 'green',
      ),
      title: Text(debt?.name ?? name ?? 'บัญชีหนี้'),
    );
  }
}
