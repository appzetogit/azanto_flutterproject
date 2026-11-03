import '../common_widgets/app_refresh_indicator.dart';
import '../common_widgets/skeleton_loading.dart';
import '../common_widgets/exit_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/haptics.dart';
import '../branding/app_colors.dart';
import '../cart/widgets/floating_view_cart_bar.dart';
import '../navigation/route_names.dart';
import '../search/widgets/voice_search_dialog.dart';
import '../../data/models/restaurant_model.dart';
import '../../data/models/food_model.dart';
import '../orders/viewmodels/active_order_viewmodel.dart';
import '../common_widgets/collapsing_header_delegate.dart';
import 'screens/home_filter_screen.dart';
import 'viewmodels/banners_viewmodel.dart';
import 'viewmodels/home_viewmodel.dart';
import 'viewmodels/veg_filter_provider.dart';
import 'widgets/category_list.dart';
import 'widgets/home_header_banner.dart';
import 'widgets/nearby_restaurants_list.dart';
import 'widgets/popular_brands_list.dart';
import 'widgets/promo_banner_carousel.dart';
import 'widgets/popular_items_list.dart';
import 'widgets/restaurant_card.dart';
import '../../quick/ui/common/widgets/inputs/search_bar_widget.dart';
import 'viewmodels/zone_viewmodel.dart';
import 'widgets/zone_coming_soon_widget.dart';
import '../cart/viewmodels/cart_viewmodel.dart';
import '../../shared/widgets/brand_footer.dart';
import '../../shared/widgets/zone_unavailable_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<FloatingViewCartBarState> _cartBarKey =
      GlobalKey<FloatingViewCartBarState>();
  final ScrollController _scrollController = ScrollController();
  String _selectedCategory = 'All';
  // Flips once the sticky header has mostly collapsed, so the status bar
  // icon color can switch from light (over the banner) to dark (over the
  // plain background) — only triggers a rebuild on the threshold crossing,
  // not on every scroll frame.
  bool _headerCollapsed = false;

  // One consistent rhythm for the whole feed instead of a different gap
  // between every pair of sections: a tight gap under each section's own
  // title, and a slightly larger one separating one section from the next.
  double get _headerGap => 8.h;
  double get _sectionGap => 16.h;

  // Sticky header geometry: the search bar + categories row travel together
  // as one fixed-height block from their original (floating-over-the-banner)
  // position up to a pinned spot below the status bar.
  double get _stickyBlockHeight =>
      50.h + 4.h + 96.h; // search + gap + categories
  double get _bannerToBlockOverlap =>
      26.h; // preserves the original floating-overlap look
  double get _collapsedTopPadding =>
      8.h; // breathing room below the status bar once pinned
  double get _shadowRoom =>
      8.h; // clip-safe room for the sticky block's elevation shadow
  double get _headerRange =>
      315.h - _bannerToBlockOverlap - _collapsedTopPadding;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(activeOrderViewModelProvider.notifier).fetchActiveOrder();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final collapsed = _scrollController.offset > _headerRange * 0.7;
    if (collapsed != _headerCollapsed) {
      setState(() => _headerCollapsed = collapsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeViewModelProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final zoneModel = ref.watch(zoneViewModelProvider).asData?.value;
    final nearbyAsync = homeState.nearbyRestaurants;
    final restaurants = nearbyAsync.asData?.value ?? [];

    final bool isZoneUnserviceable = zoneModel != null && !zoneModel.isInService;

    // Definitely outside every configured zone — not "nothing nearby today",
    // a flat "we don't deliver here at all". Replaces the whole page rather
    // than the in-page ZoneComingSoonWidget card further down, which is for
    // the milder in-zone-but-empty case below and would otherwise leave the
    // search bar and category chips sitting above a page with nothing they
    // can do.
    if (isZoneUnserviceable) {
      return const ZoneUnavailableScreen();
    }

    // Past the check above, so this can only mean "in zone, nothing nearby".
    final bool noRestaurantsAvailable =
        nearbyAsync is AsyncData && restaurants.isEmpty;

    final topInset = MediaQuery.of(context).padding.top;
    // Matches HomeHeaderBanner's own height calc exactly, so the sticky
    // header's expanded size is pixel-identical to the old static layout.
    final bannerHeight = topInset + 315.h;
    // Expanded: the block floats over the banner exactly as before.
    final expandedBlockTop = bannerHeight - _bannerToBlockOverlap;
    // Collapsed: the block sits pinned just below the status bar.
    final collapsedBlockTop = topInset + _collapsedTopPadding;
    final expandedHeaderExtent =
        expandedBlockTop + _stickyBlockHeight + _shadowRoom;
    final collapsedHeaderExtent =
        collapsedBlockTop + _stickyBlockHeight + _shadowRoom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showExitConfirmationDialog(context);
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (_headerCollapsed && !isDark)
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              AppRefreshIndicator(
                onRefresh: () async {
                  await ref.read(homeViewModelProvider.notifier).loadHomeData(isRefresh: true, retryZone: true);
                  await ref.read(activeOrderViewModelProvider.notifier).fetchActiveOrder(isRefresh: true);
                  // Banners are their own provider, so loadHomeData does not
                  // touch them — without this a banner the admin just published
                  // would not appear until the app was restarted.
                  ref.invalidate(promoBannersProvider);
                  ref.invalidate(heroBannersProvider);
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // 1. Hero Header Banner + sticky Search Bar & Categories —
                    // the banner fades/collapses on scroll-up, and the search
                    // bar + categories block sticks to the top once pinned.
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: CollapsingHeaderDelegate(
                        expandedExtent: expandedHeaderExtent,
                        collapsedExtent: collapsedHeaderExtent,
                        expandedBlockTop: expandedBlockTop,
                        collapsedBlockTop: collapsedBlockTop,
                        blockHeight: _stickyBlockHeight,
                        backdropColor: isDark
                            ? AppColors.backgroundDark
                            : AppColors.backgroundLight,
                        bannerDriftUp: 30.h,
                        banner: const HomeHeaderBanner(),
                        stickyBlock: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSearchBar(context, isDark),
                            SizedBox(height: 4.h),
                            CategoryList(
                              categories:
                                  homeState.categories.asData?.value ??
                                  const [],
                              selectedCategoryName: _selectedCategory,
                              onCategorySelected: (catName) {
                                setState(() {
                                  _selectedCategory = catName;
                                });
                                // The filtered sections start below the tall
                                // banner, so without this a tap looks like it
                                // did nothing — pin the header and bring the
                                // results up under the chips.
                                if (_scrollController.hasClients &&
                                    _scrollController.offset < _headerRange) {
                                  _scrollController.animateTo(
                                    _headerRange,
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOutCubic,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (noRestaurantsAvailable) ...[
                            SizedBox(height: _sectionGap - _shadowRoom),

                            // 5b. Promotional Cards (admin-uploaded carousels)
                            ref.watch(promoBannersProvider).when(
                                  data: (banners) => banners.isEmpty
                                      ? const SizedBox.shrink()
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            PromoBannerCarousel(banners: banners),
                                            SizedBox(height: _sectionGap),
                                          ],
                                        ),
                                  loading: () => const SizedBox.shrink(),
                                  error: (err, stack) => const SizedBox.shrink(),
                                ),

                            ref.watch(store99BannersProvider).when(
                                  data: (banners) => banners.isEmpty
                                      ? const SizedBox.shrink()
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            PromoBannerCarousel(banners: banners),
                                            SizedBox(height: _sectionGap),
                                          ],
                                        ),
                                  loading: () => const SizedBox.shrink(),
                                  error: (err, stack) => const SizedBox.shrink(),
                                ),

                            // Coming Soon Message Widget when no restaurants are available in zone
                            const ZoneComingSoonWidget(),

                            SizedBox(height: _sectionGap),

                            const BrandFooter(
                              wordmark: 'azanto',
                              tagline:
                                  'Your favourite restaurants, delivered to your doorstep.',
                            ),

                            SizedBox(height: 100.h),
                          ] else ...[
                            // The sticky header already reserves _shadowRoom
                            // worth of clearance below the categories row, so
                            // only the remainder of _sectionGap is needed here
                            // to keep the total spacing identical to before.
                            SizedBox(height: _sectionGap - _shadowRoom),

                            // 3. Quick Feature Filter Pills (Trending Now, ₹99 Store, Buy 1 Get 1 Free, Free Delivery, Pure Veg, Near You)
                            _buildQuickFilterPills(isDark),

                            SizedBox(height: _sectionGap),

                            // 4. 99 STORE Section
                            homeState.popularFoods.when(
                              data: (foods) => PopularItemsList(
                                foods: _filterFoods(
                                  foods,
                                  ref.watch(vegFilterProvider),
                                ),
                                restaurants:
                                    homeState.nearbyRestaurants.asData?.value ??
                                    const [],
                                cartBarKey: _cartBarKey,
                                onAddToCartAnimationComplete: () {
                                  _cartBarKey.currentState?.bump();
                                },
                              ),
                              loading: () => const SkeletonBanner(height: 140),
                              error: (err, stack) => const SizedBox.shrink(),
                            ),

                            SizedBox(height: _sectionGap),

                            // 5. RESTAURANTS NEAR YOU Section
                            _buildSectionHeader(
                              title: 'RESTAURANTS NEAR YOU',
                              onViewAll: () => context.push(RouteNames.search),
                              isDark: isDark,
                            ),
                            SizedBox(height: _headerGap),
                            homeState.nearbyRestaurants.when(
                              data: (restaurants) => NearbyRestaurantsList(
                                restaurants: _filterRestaurants(restaurants),
                              ),
                              loading: () => const SkeletonBanner(height: 180),
                              error: (err, stack) => const SizedBox.shrink(),
                            ),

                            SizedBox(height: _sectionGap),

                            // 5b. Promotional Cards (admin-uploaded carousels)
                            ref.watch(promoBannersProvider).when(
                                  data: (banners) => banners.isEmpty
                                      ? const SizedBox.shrink()
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            PromoBannerCarousel(banners: banners),
                                            SizedBox(height: _sectionGap),
                                          ],
                                        ),
                                  loading: () => const SizedBox.shrink(),
                                  error: (err, stack) => const SizedBox.shrink(),
                                ),

                            ref.watch(store99BannersProvider).when(
                                  data: (banners) => banners.isEmpty
                                      ? const SizedBox.shrink()
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            PromoBannerCarousel(banners: banners),
                                            SizedBox(height: _sectionGap),
                                          ],
                                        ),
                                  loading: () => const SizedBox.shrink(),
                                  error: (err, stack) => const SizedBox.shrink(),
                                ),

                            // 6. POPULAR BRANDS Section
                            _buildSectionHeader(
                              title: 'POPULAR BRANDS',
                              onViewAll: () => context.push(RouteNames.search),
                              isDark: isDark,
                            ),
                            SizedBox(height: _headerGap),
                            homeState.nearbyRestaurants.when(
                              data: (restaurants) => PopularBrandsList(
                                restaurants: _filterRestaurants(restaurants),
                              ),
                              loading: () => const SkeletonBanner(height: 80),
                              error: (err, stack) => const SizedBox.shrink(),
                            ),

                            SizedBox(height: _sectionGap),

                            // 8. RESTAURANTS DELIVERING TO YOU Vertical List Section
                            homeState.nearbyRestaurants.when(
                              data: (allRestaurants) {
                                final restaurants = _filterRestaurants(
                                  allRestaurants,
                                );
                                if (restaurants.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final totalCount = restaurants.length;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionHeader(
                                      title:
                                          '$totalCount RESTAURANTS DELIVERING TO YOU',
                                      onViewAll: null,
                                      isDark: isDark,
                                    ),
                                    SizedBox(height: _headerGap),
                                    ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: restaurants.length,
                                      itemBuilder: (context, index) {
                                        return RestaurantCard(
                                          restaurant: restaurants[index],
                                          index: index,
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                              loading: () => const SkeletonRestaurantList(count: 3),
                              error: (err, stack) => const SizedBox.shrink(),
                            ),

                            // Sign-off at the end of the feed, the same one
                            // Mart carries.
                            const BrandFooter(
                              wordmark: 'azanto',
                              tagline:
                                  'Your favourite restaurants, delivered to your doorstep.',
                            ),

                            SizedBox(height: 100.h),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Floating View Cart Bar
              FloatingViewCartBar(
                key: _cartBarKey,
                onTap: () {
                  Haptics.light();
                  context.go(RouteNames.cart);
                },
                onRemove: () {
                  Haptics.light();
                  ref.read(cartViewModelProvider.notifier).clearCart();
                },
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  /// Rotating search hints, taken from the categories the backend returned so
  /// the field never advertises something the menu does not have.
  List<String> get _searchHints {
    final names = ref
        .read(homeViewModelProvider)
        .categories
        .asData
        ?.value
        .map((c) => c.name.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    return (names == null || names.isEmpty) ? const ['dishes'] : names;
  }

  /// 2. Search Bar + Voice Search (Container 1) & VEG Toggle Pill (Container 2)
  Widget _buildSearchBar(BuildContext context, bool isDark) {
    final isVegOnly = ref.watch(vegFilterProvider);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0.w),
      child: Row(
        children: [
          // Container 1: the shared animated search field.
          //
          // Food used to draw its own static bar with a fixed hint string. This
          // is the same widget Mart uses -- rotating hints, same shape, same
          // motion -- so the two verticals no longer drift apart, and its hints
          // are the real category names rather than a compiled-in list.
          Expanded(
            child: SearchBarWidget(
              readOnly: true,
              hintRotation: _searchHints,
              onTap: () {
                Haptics.light();
                context.push(RouteNames.search);
              },
              onMicTap: () async {
                Haptics.light();
                final query = await VoiceSearchDialog.show(context);
                if (query != null && query.trim().isNotEmpty && context.mounted) {
                  context.push(RouteNames.search, extra: query.trim());
                }
              },
            ),
          ),
          SizedBox(width: 10.w),

          // Container 2: Separate VEG Toggle Pill Button
          InkWell(
            onTap: () {
              Haptics.light();
              ref.read(vegFilterProvider.notifier).toggle();
            },
            borderRadius: BorderRadius.circular(20.r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 50.h,
              width: 64.w,
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isVegOnly
                      ? AppColors.success
                      : (isDark
                            ? AppColors.borderDark
                            : const Color(0xFFEEEEEE)),
                  width: isVegOnly ? 1.5 : 1.0,
                ),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: isVegOnly
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.shadow1,
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 4.sp,
                        height: 4.sp,
                        decoration: BoxDecoration(
                          color: isVegOnly
                              ? AppColors.success
                              : (isDark
                                    ? AppColors.textSecondaryDark
                                    : const Color(0xFF008A45)),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        'VEG',
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w900,
                          color: isVegOnly
                              ? AppColors.success
                              : (isDark
                                    ? AppColors.textSecondaryDark
                                    : const Color(0xFF008A45)),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 34.w,
                    height: 18.h,
                    padding: EdgeInsets.all(2.r),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.r),
                      color: isVegOnly
                          ? AppColors.success
                          : (isDark
                                ? const Color(0xFF3B3B3B)
                                : const Color(0xFFE0E0E0)),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: isVegOnly
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 14.h,
                        height: 14.h,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Quick Feature Filter Pills Row
  Widget _buildQuickFilterPills(bool isDark) {
    final pills = [
      {
        'icon': Icons.local_fire_department_rounded,
        'title': 'Trending',
        'highlight': 'Now',
        'bg': AppColors.primary.withValues(alpha: 0.12),
        'color': AppColors.primary,
        'onTap': () => _openFilter(
          title: 'Trending Now',
          emptyMessage: 'No trending restaurants right now',
          emptyIcon: Icons.local_fire_department_rounded,
          // HomeFilterScreen recognizes this title and fetches its own
          // backend-ranked-by-orders list instead of running a predicate over
          // nearbyRestaurants, so this is never evaluated — kept truthful
          // rather than a bare `(_) => true` in case that ever changes.
          matches: (r) => r.isFeatured,
        ),
      },
      {
        'icon': Icons.currency_rupee_rounded,
        'title': '99',
        'highlight': 'Store',
        'bg': const Color(0xFFFFF9E6),
        'color': const Color(0xFFF57F17),
        'onTap': () {
          Haptics.light();
          context.push(RouteNames.store99);
        },
      },
      {
        'icon': Icons.bolt_rounded,
        'title': 'Near & Fast',
        'highlight': '',
        'bg': Colors.white,
        'color': const Color(0xFF16A34A),
        'textColor': const Color(0xFF111827),
        'borderColor': const Color(0xFFE2E8F0),
        'onTap': () => _openFilter(
          title: 'Near & Fast',
          emptyMessage: 'No nearby fast-delivery restaurants right now',
          emptyIcon: Icons.bolt_rounded,
          // HomeFilterScreen recognizes this title and fetches its own
          // 10km-radius, nearest-first list instead of running a predicate
          // over nearbyRestaurants (which is zone-wide with no radius, so
          // this flag never matched), so this is never evaluated — kept
          // truthful rather than a bare `(_) => true` in case that changes.
          matches: (r) => r.isNearAndFast,
        ),
      },
      {
        'icon': Icons.shopping_bag_outlined,
        'title': 'Buy 1 Get 1',
        'highlight': 'Free',
        'bg': AppColors.success.withValues(alpha: 0.12),
        'color': AppColors.success,
        'onTap': () => _openFilter(
          title: 'Buy 1 Get 1 Free',
          emptyMessage: 'No Buy 1 Get 1 Free meals available right now',
          emptyIcon: Icons.card_giftcard_rounded,
          matches: (r) => r.offerBadges.any(
            (b) => RegExp(
              r'buy\s*1|b\s*1\s*g\s*1',
              caseSensitive: false,
            ).hasMatch(b),
          ),
        ),
      },
      {
        'icon': Icons.directions_bike_rounded,
        'title': 'FREE',
        'highlight': 'Delivery',
        'bg': AppColors.primary.withValues(alpha: 0.12),
        'color': AppColors.primary,
        'onTap': () => _openFilter(
          title: 'Free Delivery',
          emptyMessage: 'No free-delivery restaurants nearby right now',
          emptyIcon: Icons.delivery_dining_rounded,
          // Only restaurants the backend explicitly marks free-delivery. The
          // listing carries no delivery fee at all, so `deliveryFee` reads 0
          // for every restaurant and `<= 0` matched the whole list.
          matches: (r) => r.isFreeDelivery,
        ),
      },
      {
        'icon': Icons.eco_rounded,
        'title': 'Pure Veg',
        'highlight': '',
        'bg': AppColors.success.withValues(alpha: 0.12),
        'color': AppColors.success,
        // No per-restaurant veg flag exists on the backend yet — this filters
        // the real food list below (same switch as the VEG toggle) rather
        // than fabricating one.
        'onTap': () {
          Haptics.light();
          ref.read(vegFilterProvider.notifier).set(true);
        },
      },
    ];

    return SizedBox(
      height: 38.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: pills.length,
        separatorBuilder: (context, index) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final p = pills[index];
          final bgColor = isDark ? AppColors.surfaceDark : (p['bg'] as Color? ?? Colors.white);
          final iconColor = p['color'] as Color;
          final textColor = (p['textColor'] as Color?) ??
              (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
          final borderColor = (p['borderColor'] as Color?) ?? iconColor.withValues(alpha: 0.15);

          return InkWell(
            borderRadius: BorderRadius.circular(20.r),
            onTap: p['onTap'] as VoidCallback,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: borderColor,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(p['icon'] as IconData, color: iconColor, size: 17.sp),
                  SizedBox(width: 6.w),
                  Text(
                    p['title'] as String,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                  if ((p['highlight'] as String).isNotEmpty) ...[
                    SizedBox(width: 3.w),
                    Text(
                      p['highlight'] as String,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openFilter({
    required String title,
    required String emptyMessage,
    required IconData emptyIcon,
    required bool Function(RestaurantModel) matches,
  }) {
    Haptics.light();
    context.push(
      RouteNames.homeFilter,
      extra: HomeFilterArgs(
        title: title,
        emptyMessage: emptyMessage,
        emptyIcon: emptyIcon,
        matches: matches,
      ),
    );
  }

  /// Section Header (Title + Azanto Primary View All >)
  Widget _buildSectionHeader({
    required String title,
    required VoidCallback? onViewAll,
    required bool isDark,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          if (onViewAll != null)
            InkWell(
              onTap: () {
                Haptics.light();
                onViewAll();
              },
              child: Row(
                children: [
                  Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                    size: 16.sp,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Whether [text] mentions the selected category (plural-tolerant, so
  /// "Pizzas" still matches "pizza").
  bool _matchesCategory(String text) {
    final query = _selectedCategory.toLowerCase().trim();
    final singular = query.endsWith('s')
        ? query.substring(0, query.length - 1)
        : query;
    final haystack = text.toLowerCase();
    return haystack.contains(query) || haystack.contains(singular);
  }

  /// A dish belongs to a category when the backend filed it there
  /// ([FoodModel.categoryName] — the home chips are exactly the categories
  /// dishes are filed under) or its name/description mentions it.
  bool _foodInCategory(FoodModel f) =>
      _matchesCategory('${f.categoryName} ${f.name} ${f.description}');

  List<FoodModel> _filterFoods(List<FoodModel> foods, bool isVegOnly) {
    var result = foods;
    if (_selectedCategory != 'All' && _selectedCategory != 'More') {
      result = result.where(_foodInCategory).toList();
    }
    if (isVegOnly) {
      result = result.where((f) => f.isVeg).toList();
    }
    return result;
  }

  List<RestaurantModel> _filterRestaurants(List<RestaurantModel> restaurants) {
    final isVegOnly = ref.watch(vegFilterProvider);
    var list = restaurants;
    if (isVegOnly) {
      // Veg Mode filters DISHES, not whole restaurants.
      //
      // This used to keep only `isPureVeg` restaurants. No restaurant in the
      // catalogue is flagged pure-veg, so turning Veg Mode on emptied the
      // entire home screen. A restaurant that serves veg dishes belongs in a
      // veg listing — you simply see its veg dishes — which is how every major
      // food app behaves.
      //
      // Membership is derived from the real menu already loaded for the home
      // screen, so nothing is hardcoded: a restaurant stays if it is pure-veg
      // or if any of its loaded dishes is veg.
      final vegRestaurantIds = ref
              .read(homeViewModelProvider)
              .popularFoods
              .asData
              ?.value
              .where((f) => f.isVeg)
              .map((f) => f.restaurantId)
              .toSet() ??
          const <String>{};
      list = list
          .where((r) => r.isPureVeg || vegRestaurantIds.contains(r.id))
          .toList();
    }
    if (_selectedCategory == 'All' || _selectedCategory == 'More') {
      return list;
    }
    // A restaurant is in the category if it serves a dish from it — most
    // restaurants selling pizza don't say "pizza" in their name or cuisines.
    final servingIds = ref
            .read(homeViewModelProvider)
            .popularFoods
            .asData
            ?.value
            .where(_foodInCategory)
            .map((f) => f.restaurantId)
            .toSet() ??
        const <String>{};
    return list
        .where((r) =>
            servingIds.contains(r.id) ||
            _matchesCategory(
              '${r.name} ${r.tags.join(' ')} ${r.restaurantTags.join(' ')}',
            ))
        .toList();
  }
}
