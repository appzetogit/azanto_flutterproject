import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Pins the search row to the top of Mart home while everything below scrolls.
///
/// A fixed-extent delegate rather than a collapsing one: the search bar is the
/// only thing that must stay reachable, so min and max extent are equal and the
/// bar neither shrinks nor fades. The location header above it is a normal
/// sliver and scrolls away, which is the intended behaviour.
///
/// The background is painted opaquely here — without it, content scrolling
/// underneath shows through the gaps around the bar.
class PinnedSearchHeader extends SliverPersistentHeaderDelegate {
  const PinnedSearchHeader({
    required this.child,
    required this.extent,
    this.topInset = 0,
  });

  final Widget child;
  final double extent;

  /// Status-bar height. Reserved inside the header so that once pinned the bar
  /// sits below the notch instead of under the clock.
  final double topInset;

  @override
  double get minExtent => extent + topInset;

  @override
  double get maxExtent => extent + topInset;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // A hairline appears only once something has scrolled under the bar, so the
    // header reads as flat until it is actually overlapping content.
    final lifted = shrinkOffset > 0 || overlapsContent;
    return Container(
      height: extent + topInset,
      padding: EdgeInsets.only(top: topInset),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          bottom: BorderSide(
            color: lifted ? context.semantic.border : Colors.transparent,
          ),
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant PinnedSearchHeader old) =>
      old.child != child || old.extent != extent || old.topInset != topInset;
}
