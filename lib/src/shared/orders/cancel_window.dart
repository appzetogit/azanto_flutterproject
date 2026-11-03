import 'dart:async';

import 'package:flutter/widgets.dart';

/// How long after placing an order the customer may still cancel it.
///
/// Mirrors `CANCELLATION_WINDOW_MS` in the backend's `order.service.js`, which
/// is the value that actually decides. This one only draws the countdown, so if
/// the two ever disagree the server still wins and the app shows a refusal.
const kCancelWindow = Duration(seconds: 90);

/// The moment cancellation closes for an order placed at [placedAt].
///
/// [placedAt] is the server's `createdAt`, never a locally stamped time — that
/// is what makes the countdown resume correctly after the app is closed and
/// reopened instead of restarting at a full minute.
DateTime cancelWindowEndsAt(DateTime placedAt) => placedAt.add(kCancelWindow);

/// Whether the window is still open. A null [placedAt] is treated as open, so a
/// missing timestamp falls back to the status rules rather than silently
/// removing the button — the backend refuses late calls either way.
bool isCancelWindowOpen(DateTime? placedAt) =>
    placedAt == null || DateTime.now().isBefore(cancelWindowEndsAt(placedAt));

/// Rebuilds once a second until [deadline], then stops.
///
/// One timer per mounted countdown and no network at all: the deadline is
/// already known, so ticking is pure arithmetic. [onExpired] fires exactly once,
/// after the frame, and is where the screen refreshes its order so the rest of
/// the UI catches up with the closed window.
class CancelWindowCountdown extends StatefulWidget {
  const CancelWindowCountdown({
    super.key,
    required this.deadline,
    required this.builder,
    this.onExpired,
  });

  final DateTime deadline;

  /// Called with the time left, clamped at zero.
  final Widget Function(BuildContext context, Duration remaining) builder;

  final VoidCallback? onExpired;

  @override
  State<CancelWindowCountdown> createState() => _CancelWindowCountdownState();
}

class _CancelWindowCountdownState extends State<CancelWindowCountdown> {
  Timer? _ticker;
  late Duration _remaining;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _remaining = _left();
    if (_remaining > Duration.zero) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else {
      _fireExpired();
    }
  }

  @override
  void didUpdateWidget(CancelWindowCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A refreshed order can arrive with a different deadline; recompute rather
    // than keep counting towards the old one.
    if (oldWidget.deadline != widget.deadline) {
      _notified = false;
      _tick();
    }
  }

  /// Recomputed from the deadline every tick, never decremented. A decremented
  /// counter drifts whenever a tick is late — and it is always late while the
  /// app is backgrounded, which is exactly when a minute passes unwatched.
  Duration _left() {
    final left = widget.deadline.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _remaining = _left());
    if (_remaining == Duration.zero) {
      _ticker?.cancel();
      _ticker = null;
      _fireExpired();
    }
  }

  void _fireExpired() {
    if (_notified) return;
    _notified = true;
    final onExpired = widget.onExpired;
    if (onExpired == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onExpired();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _remaining);
}

/// `mm:ss`, the format the countdown label is specified in.
String formatCancelRemaining(Duration remaining) {
  final total = remaining.inSeconds;
  final minutes = (total ~/ 60).toString().padLeft(2, '0');
  final seconds = (total % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Shows [builder] only while the order may still be cancelled, and hides it the
/// second the window closes.
///
/// Every screen that offers cancellation goes through this, so the three of them
/// (food details, food tracking, mart details) cannot drift apart on when the
/// button disappears. Each still draws its own button — only the timing is
/// shared.
///
/// [statusAllows] carries the vertical's existing status rule; this widget adds
/// the clock and nothing else. When both agree the order is cancellable it
/// renders [builder] with the time left, and calls [onExpired] once at zero so
/// the screen can refetch and let the rest of the UI catch up.
class CancelWindowGate extends StatelessWidget {
  const CancelWindowGate({
    super.key,
    required this.placedAt,
    required this.statusAllows,
    required this.builder,
    this.onExpired,
  });

  /// The server's order-creation timestamp.
  final DateTime? placedAt;

  final bool statusAllows;
  final Widget Function(BuildContext context, Duration remaining) builder;
  final VoidCallback? onExpired;

  @override
  Widget build(BuildContext context) {
    if (!statusAllows) return const SizedBox.shrink();
    // No timestamp means no countdown to draw, but the status rule still says
    // yes — offer the button and let the backend arbitrate.
    if (placedAt == null) {
      return builder(context, kCancelWindow);
    }

    return CancelWindowCountdown(
      deadline: cancelWindowEndsAt(placedAt!),
      onExpired: onExpired,
      builder: (context, remaining) => remaining == Duration.zero
          ? const SizedBox.shrink()
          : builder(context, remaining),
    );
  }
}
