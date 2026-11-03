import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/restaurant_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/smart_image.dart';
import '../../navigation/route_names.dart';

/// Popular brands, drifting slowly on their own.
///
/// The row auto-scrolls so the brands beyond the fold are discoverable without
/// a swipe, but it is a plain [ListView] underneath — dragging still works, and
/// the drift yields to the user rather than fighting them: it pauses on touch
/// and resumes a moment after release.
class PopularBrandsList extends StatefulWidget {
  final List<RestaurantModel> restaurants;

  const PopularBrandsList({
    super.key,
    required this.restaurants,
  });

  @override
  State<PopularBrandsList> createState() => _PopularBrandsListState();
}

class _PopularBrandsListState extends State<PopularBrandsList> {
  final _controller = ScrollController();
  Timer? _ticker;
  Timer? _resume;

  /// Slow enough to read: ~24 logical px per second, stepped every frame-ish
  /// interval so the motion is continuous rather than a visible hop.
  static const _tick = Duration(milliseconds: 32);
  static const _pxPerTick = 0.8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    _ticker?.cancel();
    if (!mounted || widget.restaurants.length < 2) return;
    _ticker = Timer.periodic(_tick, (_) {
      if (!_controller.hasClients) return;
      final max = _controller.position.maxScrollExtent;
      if (max <= 0) return;
      final next = _controller.offset + _pxPerTick;
      // Loop back to the start instead of stalling at the end, so the row keeps
      // presenting brands for as long as home is on screen.
      _controller.jumpTo(next >= max ? 0 : next);
    });
  }

  void _pauseForDrag() {
    _ticker?.cancel();
    _resume?.cancel();
    // Give the user their scroll back; only take over again once they stop.
    _resume = Timer(const Duration(seconds: 3), _start);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _resume?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = widget.restaurants;
    if (restaurants.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sized to the avatar + two text lines actually rendered — was 88,
    // leaving dead space below every chip before the section gap started.
    return SizedBox(
      height: 88.h,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollStartNotification && n.dragDetails != null) {
            _pauseForDrag();
          }
          return false;
        },
        child: ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: restaurants.length,
        itemBuilder: (context, index) {
          final restaurant = restaurants[index];
          final name = restaurant.name;
          final time = restaurant.deliveryTime;
          final logo = restaurant.imageUrl;

          return GestureDetector(
            onTap: () {
              Haptics.light();
              context.push(RouteNames.restaurantDetail, extra: restaurant);
            },
            child: Container(
              width: 72.w,
              margin: EdgeInsets.only(right: 12.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Circular Brand Logo Avatar Container
                  Container(
                    width: 48.w,
                    height: 48.h,
                    padding: EdgeInsets.all(7.r),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
                        width: 1.0,
                      ),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: AppColors.shadow1,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: ClipOval(
                      child: SmartImage(
                        url: logo,
                        category: ImageCategory.restaurant,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: 3.h),

                  // Brand Title
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 1.h),

                  // Delivery Time
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF757575),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}
