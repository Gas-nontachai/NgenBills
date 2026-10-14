import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/sheets/app_bottom_sheet.dart';
import '../../domain/entities/debt.dart';
import '../widgets/account_avatar.dart';
import '../widgets/debt_direction_chip.dart';

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
    this.onReorder,
  });
  final List<Debt> accounts;
  final String selectedId;
  final String? defaultId;
  final Future<void> Function(List<String>)? onReorder;

  static Future<AccountPickerResult?> open(
    BuildContext context,
    List<Debt> accounts,
    String selectedId,
    String? defaultId, {
    Future<void> Function(List<String>)? onReorder,
  }) => showAppSheet<AccountPickerResult>(
    context,
    AccountPickerSheet(
      accounts: accounts,
      selectedId: selectedId,
      defaultId: defaultId,
      onReorder: onReorder,
    ),
  );

  @override
  State<AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends State<AccountPickerSheet> {
  late List<Debt> _accounts;
  bool _saving = false;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _accounts = List.of(widget.accounts);
    final defaultIndex = _accounts.indexWhere((a) => a.id == widget.defaultId);
    if (defaultIndex > 0) {
      _accounts.insert(0, _accounts.removeAt(defaultIndex));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final index = _accounts.indexWhere((a) => a.id == widget.selectedId);
      _scroll.jumpTo(
        (index * 64.0).clamp(0.0, _scroll.position.maxScrollExtent),
      );
    });
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_saving || _search.text.trim().isNotEmpty || widget.onReorder == null) {
      return;
    }
    if (_accounts[oldIndex].id == widget.defaultId) return;
    if (_accounts.first.id == widget.defaultId && newIndex == 0) {
      newIndex = 1;
    }
    if (oldIndex == newIndex) return;
    final previous = List<Debt>.of(_accounts);
    setState(() {
      _accounts.insert(newIndex, _accounts.removeAt(oldIndex));
      _saving = true;
    });
    try {
      await widget.onReorder!(_accounts.map((a) => a.id).toList());
    } catch (_) {
      if (!mounted) return;
      setState(() => _accounts = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกลำดับไม่สำเร็จ กรุณาลองอีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    final accounts = _accounts
        .where((a) => a.name.toLowerCase().contains(query))
        .toList();
    final media = MediaQuery.of(context);
    return PopScope(
      canPop: !_saving,
      child: Padding(
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
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _search,
                    enabled: !_saving,
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
                        : ReorderableListView.builder(
                            scrollController: _scroll,
                            buildDefaultDragHandles: false,
                            onReorderItem: _reorder,
                            itemExtent: media.textScaler.scale(14) <= 14
                                ? 64
                                : null,
                            itemCount: accounts.length,
                            itemBuilder: (context, index) {
                              final debt = accounts[index];
                              final selected = debt.id == widget.selectedId;
                              return ListTile(
                                key: ValueKey(debt.id),
                                contentPadding: EdgeInsets.zero,
                                selected: selected,
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.onReorder != null &&
                                        debt.id != widget.defaultId)
                                      ReorderableDragStartListener(
                                        index: index,
                                        enabled: !_saving && query.isEmpty,
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Icon(
                                            Icons.drag_handle,
                                            semanticLabel:
                                                'ลากเพื่อจัดลำดับบัญชี',
                                            color: !_saving && query.isEmpty
                                                ? null
                                                : Theme.of(context)
                                                      .disabledColor,
                                          ),
                                        ),
                                      ),
                                    AccountAvatar(
                                      iconKey: debt.iconKey,
                                      colorKey: debt.colorKey,
                                    ),
                                  ],
                                ),
                                title: Text(
                                  debt.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (debt.id == widget.defaultId)
                                      const Text(
                                        'บัญชีหลัก',
                                        style: AppTypography.caption,
                                      ),
                                    DebtDirectionChip(
                                      direction: debt.direction,
                                    ),
                                  ],
                                ),
                                trailing: Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                ),
                                onTap: _saving
                                    ? null
                                    : () => Navigator.pop(
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
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(
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
      ),
    );
  }
}
