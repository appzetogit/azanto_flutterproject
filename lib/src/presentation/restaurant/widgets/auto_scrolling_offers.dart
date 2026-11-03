import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../branding/app_colors.dart';

/// The offer strip, cycling right-to-left through every offer the backend sent.
class AutoScrollingOffers extends StatefulWidget {
  const AutoScrollingOffers({
    super.key,
    required this.offers,
    required this.itemBuilder,
    required this.height,
  });

  /// Offer lines, in the order the backend returned them.
  final List<String> offers;

  final Widget Function(BuildContext context, String offer) itemBuilder;

  /// Fixed so the surrounding card never changes height as offers rotate.
  final double height;

  static const _dwell = Duration(milliseconds: 3500);
  static const _slide = Duration(milliseconds: 600);
  static const _resumeAfter = Duration(seconds: 5);

  /// Far from zero so the strip can be swiped backwards from the start without
  /// hitting the beginning of the list.
  static const _initialPage = 10000;

  @override
  State<AutoScrollingOffers> createState() => _AutoScrollingOffersState();
}

class _AutoScrollingOffersState extends State<AutoScrollingOffers> {
  late final PageController _controller;
  Timer? _advance;
  Timer? _resume;

  @override
  void initState() {
    super.initState();
    final initialPage = widget.offers.isNotEmpty
        ? AutoScrollingOffers._initialPage -
            (AutoScrollingOffers._initialPage % widget.offers.length)
        : AutoScrollingOffers._initialPage;
    _controller = PageController(initialPage: initialPage);
    _startAdvancing();
  }

  @override
  void didUpdateWidget(AutoScrollingOffers old) {
    super.didUpdateWidget(old);
    // The admin can add or remove offers; restart advancing if list changes.
    if (old.offers.length != widget.offers.length) _startAdvancing();
  }

  void _startAdvancing() {
    _advance?.cancel();
    if (widget.offers.length < 2) return;
    _advance = Timer.periodic(AutoScrollingOffers._dwell, (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.nextPage(
        duration: AutoScrollingOffers._slide,
        curve: Curves.easeInOut,
      );
    });
  }

  /// Hands control back to the user, then resumes once they have stopped.
  void _pauseForInteraction() {
    _advance?.cancel();
    _resume?.cancel();
    _resume = Timer(AutoScrollingOffers._resumeAfter, () {
      if (mounted) _startAdvancing();
    });
  }

  @override
  void dispose() {
    _advance?.cancel();
    _resume?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offers.isEmpty) return const SizedBox.shrink();
    if (widget.offers.length == 1) {
      return SizedBox(
        height: widget.height,
        child: widget.itemBuilder(context, widget.offers.first),
      );
    }

    return SizedBox(
      height: widget.height,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // Only a real drag pauses it; the timer's own animation must not.
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _pauseForInteraction();
          }
          if (notification is ScrollEndNotification &&
              _advance?.isActive != true) {
            _pauseForInteraction();
          }
          return false;
        },
        child: PageView.builder(
          controller: _controller,
          itemBuilder: (context, index) => widget.itemBuilder(
            context,
            widget.offers[index % widget.offers.length],
          ),
        ),
      ),
    );
  }
}

/// Dedicated Premium Restaurant Offer Card Carousel.
/// Renders 1 offer at a time in a styled container card with starburst % badge,
/// main offer title, subtext, top-right "X/Y" counter, and bottom-right animated dots.
class RestaurantOffersCarouselCard extends StatefulWidget {
  const RestaurantOffersCarouselCard({
    super.key,
    required this.offers,
  });

  final List<String> offers;

  @override
  State<RestaurantOffersCarouselCard> createState() =>
      _RestaurantOffersCarouselCardState();
}

class _RestaurantOffersCarouselCardState
    extends State<RestaurantOffersCarouselCard> {
  late final PageController _controller;
  int _currentIndex = 0;
  Timer? _advanceTimer;
  Timer? _resumeTimer;

  static const _dwell = Duration(milliseconds: 3500);
  static const _slide = Duration(milliseconds: 500);
  static const _resumeAfter = Duration(seconds: 4);
  static const _initialPage = 10000;

  @override
  void initState() {
    super.initState();
    final initial = widget.offers.isNotEmpty
        ? _initialPage - (_initialPage % widget.offers.length)
        : _initialPage;
    _controller = PageController(initialPage: initial);
    _startAdvancing();
  }

  @override
  void didUpdateWidget(RestaurantOffersCarouselCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offers.length != widget.offers.length) {
      _startAdvancing();
    }
  }

  void _startAdvancing() {
    _advanceTimer?.cancel();
    if (widget.offers.length < 2) return;
    _advanceTimer = Timer.periodic(_dwell, (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.nextPage(
        duration: _slide,
        curve: Curves.easeInOut,
      );
    });
  }

  void _pauseForInteraction() {
    _advanceTimer?.cancel();
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeAfter, () {
      if (mounted) _startAdvancing();
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _resumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offers.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Stack(
        children: [
          // Center offer content in PageView
          SizedBox(
            height: 44.h,
            child: widget.offers.length == 1
                ? _buildOfferContent(widget.offers.first, isDark)
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollStartNotification &&
                          notification.dragDetails != null) {
                        _pauseForInteraction();
                      }
                      if (notification is ScrollEndNotification &&
                          _advanceTimer?.isActive != true) {
                        _pauseForInteraction();
                      }
                      return false;
                    },
                    child: PageView.builder(
                      controller: _controller,
                      onPageChanged: (pageIndex) {
                        setState(() {
                          _currentIndex = pageIndex % widget.offers.length;
                        });
                      },
                      itemBuilder: (context, index) {
                        final offerText =
                            widget.offers[index % widget.offers.length];
                        return _buildOfferContent(offerText, isDark);
                      },
                    ),
                  ),
          ),

          // Top-right counter & Bottom-right dots
          if (widget.offers.length > 1)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Page counter (e.g., 3/5)
                  Text(
                    '${_currentIndex + 1}/${widget.offers.length}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.9)
                          : const Color(0xFF0F172A),
                    ),
                  ),

                  // Indicator dots
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      widget.offers.length,
                      (dotIndex) {
                        final isActive = dotIndex == _currentIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: EdgeInsets.only(left: 3.w),
                          width: isActive ? 9.w : 4.5.w,
                          height: 4.5.h,
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary
                                : (isDark
                                    ? const Color(0xFF475569)
                                    : const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(3.r),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOfferContent(String offerText, bool isDark) {
    // Intelligently parse offer text into Title and Subtitle
    String title = offerText;
    String subtitle = 'ON SELECT ITEMS';

    if (offerText.contains('|')) {
      final parts = offerText.split('|');
      title = parts[0].trim();
      subtitle = parts.sublist(1).join(' | ').trim().toUpperCase();
    } else if (offerText.toUpperCase().contains('USE ')) {
      final idx = offerText.toUpperCase().indexOf('USE ');
      title = offerText.substring(0, idx).trim();
      final codePart = offerText.substring(idx).trim();
      subtitle = '$codePart | ON SELECT ITEMS'.toUpperCase();
    }

    if (title.isEmpty) title = offerText;

    return Row(
      children: [
        // Left Icon Badge
        _buildStarburstBadge(),
        SizedBox(width: 12.w),

        // Text Column
        Expanded(
          child: Padding(
            padding:
                EdgeInsets.only(right: widget.offers.length > 1 ? 44.w : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : const Color(0xFF64748B),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStarburstBadge() {
    return SizedBox(
      width: 32.sp,
      height: 32.sp,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(32.sp, 32.sp),
            painter: _OfferBadgeStarburstPainter(color: AppColors.primary),
          ),
          Text(
            '%',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferBadgeStarburstPainter extends CustomPainter {
  final Color color;
  _OfferBadgeStarburstPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.8;
    const points = 12;

    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = (i * math.pi) / points;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
