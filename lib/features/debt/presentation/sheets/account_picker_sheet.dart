import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/widgets/sheets/app_bottom_sheet.dart';
import '../../domain/entities/debt.dart';
import '../widgets/account_avatar.dart';

class AccountPickerResult {
  const AccountPickerResult({this.debtId, this.create = false});
  final String? debtId;
  final bool create;
}

class AccountPickerSheet extends StatefulWidget {
  const AccountPickerSheet({
    super.key,
    required this.accounts,
    required this.selectedId,
    required this.defaultId,
  });
  final List<Debt> accounts;
  final String selectedId;
  final String? defaultId;

  static Future<AccountPickerResult?> open(
    BuildContext context,
    List<Debt> accounts,
    String selectedId,
    String? defaultId,
  ) => showAppSheet<AccountPickerResult>(
    context,
    AccountPickerSheet(
      accounts: accounts,
      selectedId: selectedId,
      defaultId: defaultId,
    ),
  );

  @override
  State<AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends State<AccountPickerSheet> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final index = widget.accounts.indexWhere(
        (a) => a.id == widget.selectedId,
      );
      _scroll.jumpTo(
        (index * 76.0).clamp(0.0, _scroll.position.maxScrollExtent),
      );
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final accounts = widget.accounts
        .where((a) => a.name.toLowerCase().contains(query))
        .toList();
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: math.min(
            media.size.height * .8,
            media.size.height -
                media.viewInsets.bottom -
                media.padding.top -
                media.padding.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'เลือกบัญชี',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'ปิด',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                TextField(
                  controller: _search,
                  onChanged: (_) {
                    setState(() {});
                    if (_scroll.hasClients) _scroll.jumpTo(0);
                  },
                  decoration: InputDecoration(
                    hintText: 'ค้นหาชื่อบัญชี',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'ล้างคำค้น',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: accounts.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('ไม่พบบัญชี'),
                                TextButton(
                                  onPressed: () {
                                    _search.clear();
                                    setState(() {});
                                  },
                                  child: const Text('ล้างคำค้น'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          itemExtent: 76,
                          itemCount: accounts.length,
                          itemBuilder: (context, index) {
                            final debt = accounts[index];
                            final selected = debt.id == widget.selectedId;
                            return ListTile(
                              selected: selected,
                              leading: AccountAvatar(
                                iconKey: debt.iconKey,
                                colorKey: debt.colorKey,
                              ),
                              title: Text(
                                debt.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: debt.id == widget.defaultId
                                  ? const Text('บัญชีหลัก')
                                  : null,
                              trailing: Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                              ),
                              onTap: () => Navigator.pop(
                                context,
                                AccountPickerResult(debtId: debt.id),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      const AccountPickerResult(create: true),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มบัญชี'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
