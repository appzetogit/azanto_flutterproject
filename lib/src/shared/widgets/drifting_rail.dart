import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A horizontal rail that scrolls itself, slowly and without pausing.
///
/// Constant velocity rather than a page-snapping carousel: animating
/// card-to-card gives an accelerate/settle pulse however long the duration,
/// and the brief these rails share is "gradual, no sudden movement".
/// Advancing the offset by a few pixels each frame reads as one continuous
/// glide instead.
///
/// The list repeats so it never reaches an end to snap back from, and a
/// hand-scroll pauses the drift for [resumeAfter] so it never fights the
/// shopper.
class DriftingRail extends StatefulWidget {
  const DriftingRail({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.padding,
    this.pixelsPerSecond = 22.0,
    this.resumeAfter = const Duration(seconds: 3),
  });

  /// The number of real items. The rail repeats them internally; [itemBuilder]
  /// only ever sees an index in `0..itemCount - 1`.
  final int itemCount;

  final Widget Function(BuildContext context, int index) itemBuilder;
  final Widget Function(BuildContext context, int index)? separatorBuilder;
  final EdgeInsetsGeometry? padding;

  /// Slow enough to read a card as it passes.
  final double pixelsPerSecond;

  /// How long a hand-scroll holds the drift off before it resumes.
  final Duration resumeAfter;

  /// ponytail: repeats the list a fixed number of times instead of a true ring
  /// buffer. At ~22px/s that is days of scrolling, so the end is unreachable in
  /// any real session; swap for a modulo ring if this ever anchors a kiosk.
  static const _loops = 200;

  @override
  State<DriftingRail> createState() => _DriftingRailState();
}

class _DriftingRailState extends State<DriftingRail>
    with SingleTickerProviderStateMixin {
  final _controller = ScrollController();
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  Timer? _resume;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    // A single card cannot drift anywhere.
    if (widget.itemCount > 1) {
      _ticker = createTicker(_onTick)..start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _resume?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = elapsed - _lastTick;
    _lastTick = elapsed;
    if (_paused || !_controller.hasClients) return;

    // Guard the first frame and any pause longer than a frame, or a
    // backgrounded app would resume with one large jump — the exact thing this
    // avoids.
    final seconds = dt.inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds <= 0 || seconds > 0.1) return;

    final next = _controller.offset + widget.pixelsPerSecond * seconds;
    if (next >= _controller.position.maxScrollExtent) return;
    _controller.jumpTo(next);
  }

  /// Yields to the shopper, then takes over again once they have finished.
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _paused = true;
      _resume?.cancel();
    } else if (notification is ScrollEndNotification) {
      _resume?.cancel();
      _resume = Timer(widget.resumeAfter, () {
        if (mounted) _paused = false;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.itemCount;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        itemCount: count > 1 ? count * DriftingRail._loops : count,
        separatorBuilder: (context, i) =>
            widget.separatorBuilder?.call(context, i % count) ??
            const SizedBox.shrink(),
        itemBuilder: (context, i) => widget.itemBuilder(context, i % count),
      ),
    );
  }
}
