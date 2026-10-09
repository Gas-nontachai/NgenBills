import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Horizontal gesture surface scoped to the account card. Vertical history
/// scrolling remains owned by the surrounding ListView.
class AccountSwipeCard extends StatefulWidget {
  const AccountSwipeCard({
    super.key,
    required this.child,
    required this.enabled,
    required this.last,
    required this.onPrevious,
    required this.onNext,
    required this.onCreate,
  });
  final Widget child;
  final bool enabled, last;
  final VoidCallback onPrevious, onNext, onCreate;
  @override
  State<AccountSwipeCard> createState() => _AccountSwipeCardState();
}

class _AccountSwipeCardState extends State<AccountSwipeCard> {
  Timer? _timer;
  double _drag = 0, _progress = 0;
  void _reset() {
    _timer?.cancel();
    _timer = null;
    _drag = 0;
    _progress = 0;
  }

  @override
  void didUpdateWidget(AccountSwipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _reset();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _update(DragUpdateDetails details) {
    setState(() => _drag += details.delta.dx);
    if (widget.last && _drag <= -80 && widget.enabled) {
      if (_timer != null) return;
      _timer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
        if (!mounted) return;
        setState(() => _progress = (timer.tick * 20 / 600).clamp(0.0, 1.0));
        if (_progress == 1) {
          _timer?.cancel();
          HapticFeedback.lightImpact();
        }
      });
    } else {
      _timer?.cancel();
      _timer = null;
      setState(() => _progress = 0);
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerCancel: (_) => setState(_reset),
    child: GestureDetector(
      onHorizontalDragStart: widget.enabled ? (_) => setState(_reset) : null,
      onHorizontalDragUpdate: widget.enabled ? _update : null,
      onHorizontalDragCancel: () => setState(_reset),
      onHorizontalDragEnd: widget.enabled
          ? (_) {
              final drag = _drag;
              final create = widget.last && _progress == 1;
              setState(_reset);
              if (create) {
                widget.onCreate();
              } else if (drag > 40) {
                widget.onPrevious();
              } else if (drag < -40 && !widget.last) {
                widget.onNext();
              }
            }
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.child,
          if (widget.last)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  Text(
                    _progress == 1
                        ? 'ปล่อยเพื่อเพิ่มบัญชี'
                        : 'ปัดค้างเพื่อเพิ่มบัญชี',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_drag <= -80)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: LinearProgressIndicator(value: _progress),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
