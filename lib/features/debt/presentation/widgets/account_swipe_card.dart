import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/cards/app_card.dart';

/// Keeps real account pages and the trailing creation preview in one viewport.
class AccountSwipeCard extends StatefulWidget {
  const AccountSwipeCard({
    super.key,
    required this.accountIds,
    required this.selectedId,
    required this.enabled,
    required this.itemBuilder,
    required this.onSelect,
    required this.onCreate,
    this.canCreate = true,
  });
  final List<String> accountIds;
  final String selectedId;
  final bool enabled, canCreate;
  final Widget Function(BuildContext, int, bool) itemBuilder;
  final Future<void> Function(String) onSelect;
  final FutureOr<void> Function() onCreate;

  @override
  State<AccountSwipeCard> createState() => _AccountSwipeCardState();
}

class _AccountSwipeCardState extends State<AccountSwipeCard> {
  static const _fraction = .92;
  late final PageController _pages;
  final _heights = <String, double>{};
  Timer? _hold;
  int? _pointer;
  bool _startedAtLast = false;
  int _epoch = 0;
  int? _returnEpoch;
  bool get _returning => _returnEpoch != null;
  double _page = 0, _progress = 0, _viewport = 0;
  int get _last => widget.accountIds.length - 1;

  @override
  void initState() {
    super.initState();
    final initial = widget.accountIds.indexOf(widget.selectedId);
    _page = math.max(0, initial).toDouble();
    _pages = PageController(
      initialPage: _page.toInt(),
      viewportFraction: _fraction,
    )..addListener(_positionChanged);
  }

  void _positionChanged() {
    if (mounted && _pages.hasClients) {
      setState(() => _page = _pages.page ?? _page);
    }
  }

  void _clearHold() {
    _hold?.cancel();
    _hold = null;
    _progress = 0;
  }

  void _checkHold() {
    final distance = (_page - _last) * _viewport * _fraction;
    if (!widget.enabled ||
        !widget.canCreate ||
        !_startedAtLast ||
        _pointer == null ||
        distance < 80) {
      if (_hold != null || _progress != 0) setState(_clearHold);
      return;
    }
    if (_hold != null) return;
    _hold = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!mounted) return;
      setState(() => _progress = (timer.tick * 20 / 600).clamp(0.0, 1.0));
      if (_progress == 1) {
        timer.cancel();
        HapticFeedback.lightImpact();
      }
    });
  }

  void _release({required bool canceled}) {
    final create =
        !canceled &&
        widget.enabled &&
        widget.canCreate &&
        _startedAtLast &&
        _progress == 1;
    final wasOverLast = _page > _last;
    _pointer = null;
    _startedAtLast = false;
    setState(_clearHold);
    if (!wasOverLast && !canceled) {
      _selectSettledPage();
      return;
    }
    final target = canceled
        ? widget.accountIds.indexOf(widget.selectedId).clamp(0, _last)
        : _last;
    final epoch = _epoch;
    _returnEpoch = epoch;
    // Let the scrollable finish its pointer-up handling before replacing its
    // ballistic activity with the return animation.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_pages.hasClients) return;
      if (epoch != _epoch) {
        if (_returnEpoch == epoch) _returnEpoch = null;
        _syncSelection(structureChanged: false);
        return;
      }
      await _pages.animateToPage(
        target.clamp(0, _last),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
      if (!mounted) return;
      if (_returnEpoch == epoch) _returnEpoch = null;
      if (epoch != _epoch) return;
      final current = (_pages.page ?? 0).round().clamp(0, _last);
      if (create && widget.enabled && widget.canCreate) {
        await widget.onCreate();
      } else if (!canceled &&
          widget.enabled &&
          widget.accountIds[current] != widget.selectedId) {
        await _request(widget.accountIds[current]);
      }
    });
  }

  Future<void> _request(String id) async {
    final epoch = _epoch;
    try {
      await widget.onSelect(id);
    } finally {
      if (mounted && epoch == _epoch) {
        _syncSelection(structureChanged: false);
      }
    }
  }

  void _selectSettledPage() {
    final epoch = _epoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_pages.hasClients ||
          epoch != _epoch ||
          !widget.enabled ||
          _returning ||
          _pointer != null ||
          _pages.position.isScrollingNotifier.value) {
        return;
      }
      final index = _page.round().clamp(0, _last);
      if ((_page - index).abs() >= .01) return;
      final id = widget.accountIds[index];
      if (id != widget.selectedId) unawaited(_request(id));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _syncSelection({required bool structureChanged}) {
    final epoch = _epoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients || epoch != _epoch) return;
      // Keep an in-progress touch in control. Older callbacks are discarded by
      // epoch; explicit picker/arrow selections may replace an older animation.
      if (!structureChanged && widget.enabled && _pointer != null) {
        return;
      }
      final index = widget.accountIds.indexOf(widget.selectedId);
      if (index < 0 || (_page - index).abs() < .001) return;
      _pointer = null;
      _startedAtLast = false;
      setState(_clearHold);
      if (structureChanged || (_page - index).abs() > 1.01) {
        _pages.jumpToPage(index);
      } else {
        _pages.animateToPage(
          index,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didUpdateWidget(AccountSwipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = !listEquals(oldWidget.accountIds, widget.accountIds);
    _heights.removeWhere((id, _) => !widget.accountIds.contains(id));
    if (changed || oldWidget.selectedId != widget.selectedId) {
      _epoch++;
      _syncSelection(structureChanged: changed);
    }
    if (!widget.canCreate && oldWidget.canCreate) {
      _epoch++;
      _startedAtLast = false;
      _clearHold();
    }
    if (!widget.enabled && oldWidget.enabled) {
      _epoch++;
      _pointer = null;
      _startedAtLast = false;
      _clearHold();
      _syncSelection(structureChanged: false);
    }
  }

  @override
  void dispose() {
    _clearHold();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      _viewport = box.maxWidth;
      final fallback = 400 * MediaQuery.textScalerOf(context).scale(14) / 14;
      var height = _heights[widget.selectedId] ?? fallback;
      for (var i = _page.floor() - 1; i <= _page.ceil() + 1; i++) {
        if (i >= 0 && i <= _last) {
          height = math.max(height, _heights[widget.accountIds[i]] ?? 0);
        }
      }
      final lastHeight = _heights[widget.accountIds.last] ?? height;
      final width = _viewport * _fraction - 12;
      final plusLeft =
          (_viewport - _viewport * _fraction) / 2 +
          (widget.accountIds.length - _page) * _viewport * _fraction +
          6;
      final revealed = (_viewport - plusLeft).clamp(0.0, width);
      return SizedBox(
        height: height + 12,
        child: Listener(
          onPointerDown: (event) {
            if (!widget.enabled || _pointer != null) return;
            _epoch++;
            _returnEpoch = null;
            _pointer = event.pointer;
            _startedAtLast = (_page - _last).abs() < .01;
          },
          onPointerUp: (event) {
            if (_pointer == event.pointer) _release(canceled: false);
          },
          onPointerCancel: (event) {
            if (_pointer == event.pointer) _release(canceled: true);
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.depth != 0) return false;
              if (notification is ScrollUpdateNotification &&
                  notification.dragDetails != null) {
                _checkHold();
              }
              if (notification is ScrollEndNotification &&
                  !_returning &&
                  widget.enabled) {
                _selectSettledPage();
              }
              return false;
            },
            child: PageView.builder(
              key: const ValueKey('account-carousel-pages'),
              controller: _pages,
              pageSnapping: false,
              physics: widget.enabled
                  ? _AccountPagePhysics(
                      lastAccount: () => _last,
                      parent: const ClampingScrollPhysics(),
                    )
                  : const NeverScrollableScrollPhysics(),
              itemCount: widget.accountIds.length + 1,
              itemBuilder: (context, index) {
                if (index == widget.accountIds.length) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _CreatePreview(
                        height: lastHeight,
                        revealed: revealed,
                        progress: _progress,
                      ),
                    ),
                  );
                }
                final id = widget.accountIds[index];
                final active = id == widget.selectedId;
                return Padding(
                  key: ValueKey('account-page-$id'),
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: _ReportSize(
                      onSize: (size) {
                        if (!mounted || (_heights[id] == size.height)) return;
                        setState(() => _heights[id] = size.height);
                      },
                      child: IgnorePointer(
                        ignoring: !active,
                        child: ExcludeSemantics(
                          excluding: !active,
                          child: KeyedSubtree(
                            key: active
                                ? const ValueKey('active-account-card')
                                : null,
                            child: widget.itemBuilder(context, index, active),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

class _AccountPagePhysics extends PageScrollPhysics {
  const _AccountPagePhysics({required this.lastAccount, super.parent});
  // Scrollable retains physics when its runtime type stays the same. Read the
  // current boundary so creating/deleting accounts cannot leave a stale limit.
  final int Function() lastAccount;
  @override
  _AccountPagePhysics applyTo(ScrollPhysics? ancestor) => _AccountPagePhysics(
    lastAccount: lastAccount,
    parent: buildParent(ancestor),
  );
  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final metrics = position as PageMetrics;
    final lastPixels =
        lastAccount() * metrics.viewportDimension * metrics.viewportFraction;
    if (position.pixels > lastPixels ||
        (position.pixels >= lastPixels && velocity > 0)) {
      if ((position.pixels - lastPixels).abs() <
              toleranceFor(position).distance &&
          velocity.abs() < toleranceFor(position).velocity) {
        return null;
      }
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        lastPixels,
        velocity,
        tolerance: toleranceFor(position),
      );
    }
    return super.createBallisticSimulation(position, velocity);
  }
}

class _CreatePreview extends StatelessWidget {
  const _CreatePreview({
    required this.height,
    required this.revealed,
    required this.progress,
  });
  final double height, revealed, progress;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AppCard(
      color: AppColors.primarySoft,
      padding: EdgeInsets.zero,
      child: SizedBox(
        key: const ValueKey('create-account-preview'),
        height: height,
        child: LayoutBuilder(
          builder: (context, box) {
            final visible = revealed.clamp(0.0, box.maxWidth);
            final center = math.min(
              box.maxWidth / 2,
              math.max(36.0, visible / 2),
            );
            final labelWidth = math.max(56.0, visible - 16);
            return Stack(
              children: [
                Positioned(
                  left: center - 28,
                  top: height / 2 - 44,
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          size: 30,
                          color: AppColors.primaryDark,
                        ),
                        Positioned.fill(
                          child: CircularProgressIndicator(
                            key: const ValueKey('create-account-progress'),
                            value: progress,
                            strokeWidth: 3,
                            color: AppColors.primaryDark,
                            backgroundColor: AppColors.border,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: math.max(8, center - labelWidth / 2),
                  top: height / 2 + 22,
                  width: math.min(labelWidth, box.maxWidth - 16),
                  child: Text(
                    progress == 1 ? 'ปล่อยเพื่อเพิ่มบัญชี' : 'เพิ่มบัญชีหนี้',
                    style: AppTypography.small.copyWith(
                      color: AppColors.primaryDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _ReportSize extends SingleChildRenderObjectWidget {
  const _ReportSize({required this.onSize, required super.child});
  final ValueChanged<Size> onSize;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _SizeReporter(onSize);
  @override
  void updateRenderObject(BuildContext context, _SizeReporter renderObject) =>
      renderObject.onSize = onSize;
}

class _SizeReporter extends RenderProxyBox {
  _SizeReporter(this.onSize);
  ValueChanged<Size> onSize;
  Size? _reported;
  @override
  void performLayout() {
    super.performLayout();
    if (_reported == size) return;
    _reported = size;
    final measured = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onSize(measured);
    });
  }
}
