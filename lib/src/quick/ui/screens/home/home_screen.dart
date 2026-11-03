import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/route_paths.dart';
import '../../common/widgets/misc/sound_refresh_indicator.dart';
import '../../common/widgets/misc/status_bar_style.dart';
import '../../common/widgets/states/error_state_widget.dart';
import '../../common/widgets/states/offline_banner.dart';
import '../product/product_listing/product_listing_args.dart';
import 'home_provider.dart';
import '../../../domain/model/product.dart';
import '../../../domain/model/category.dart';
import 'home_state.dart';
import '../../../domain/model/banner.dart';
import 'widgets/banner_carousel.dart';
import 'widgets/delivery_header.dart';
import 'widgets/all_category_sections_feed.dart';
import 'widgets/bestsellers_row.dart';
import 'widgets/housefull_sale_banner.dart';
import 'widgets/lowest_prices_ever_row.dart';
import 'widgets/shop_by_category_row.dart';
import 'widgets/active_order_card.dart';
import 'widgets/maavamart_maintenance_screen.dart';
import '../../../di/store_status_provider.dart';
import '../../../../shared/widgets/brand_footer.dart';
import '../../../../shared/widgets/zone_unavailable_screen.dart';
import '../../../di/zone_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final ScrollController _scrollController;
  bool _headerCollapsed = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final isCollapsed =
        _scrollController.hasClients && _scrollController.offset > 180;
    if (isCollapsed != _headerCollapsed) {
      setState(() => _headerCollapsed = isCollapsed);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    // The colour actually behind the status bar is the header gradient's top
    // stop, not the brand: reading the brand meant a deep plate (the brand's
    // own dark ramp end, or any dark category theme) still got dark icons and
    // the clock disappeared into it.
    return StatusBarStyle(
      background: martHeaderGradient(state.activeCampaign).first,
      child: Scaffold(
        backgroundColor: context.colors.surface,
        body: Stack(
          children: [
            SafeArea(
              top: false,
              bottom: false,
              child: Column(
                children: [
                  const OfflineBanner(),
                  Expanded(child: _buildBody(context, state, topPadding)),
                ],
              ),
            ),

            // Active Order Floating Card above bottom navigation
            const Positioned(
              left: 0,
              right: 0,
              bottom: 4,
              child: ActiveOrderFloatingCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, HomeState state, double topPadding) {
    // The admin-disabled case is handled one level up, by AppShell — it
    // wraps every Mart tab (not just this one), so that's the single place
    // that decides whether Mart is usable at all.

    // Definitely outside every configured zone — the same signal Food's home
    // screen uses, checked directly against the zone lookup's own status
    // rather than inferred from whether the catalog call happened to come
    // back empty (which is also true while it is still loading, and would
    // have shown nothing here at all).
    if (ref.watch(martZoneUnserviceableProvider)) {
      return const ZoneUnavailableScreen();
    }

    // In zone, but no MaavaMart store actually serves it yet — a different,
    // Mart-specific reason, kept on its own branded screen.
    if (!state.hasStoreInZone) {
      return const MaavaMartMaintenanceScreen();
    }

    if (state.failure != null &&
        state.sections.isEmpty &&
        state.categories.isEmpty) {
      return ErrorStateWidget(
        failure: state.failure!,
        onRetry: () => ref.read(homeProvider.notifier).load(refresh: true),
      );
    }

    // A fixed strip holding the status bar, painted in the header's own top
    // colour so the page still reads as one plate running under the clock.
    //
    // The scroll view starts BELOW it, which is what stops the pinned search
    // field from sliding under the status bar: a pinned sliver sticks to the
    // viewport's leading edge, and that edge used to be the top of the screen.
    return Column(
      children: [
        Container(
          height: topPadding,
          color: martHeaderGradient(state.activeCampaign).first,
        ),
        Expanded(
          child: SoundRefreshIndicator(
            onRefresh: () {
              ref.invalidate(martStoreStatusProvider);
              return ref.read(homeProvider.notifier).load(refresh: true);
            },
            child: CustomScrollView(
              controller: _scrollController,
              // Platform default over-scroll, not iOS bounce.
              //
              // BouncingScrollPhysics drags the whole list down on a pull and springs
              // it back, which read as the page jumping and re-scrolling on every
              // refresh. `AlwaysScrollable` keeps pull-to-refresh working when the
              // content is shorter than the viewport, while over-scroll falls back to
              // the platform's own (a glow on Android) so nothing moves. Food's home
              // already used exactly this.
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 1. Header, in three slivers so the search field can pin while the
                //    rest of the page scrolls past underneath it.
                SliverToBoxAdapter(
                  child: Consumer(
                    builder: (context, ref, _) {
                      // The backend decides open/closed: the seller's switch AND
                      // today's hours, the same check checkout uses. Reading the
                      // seller flag alone missed a store that was simply shut for
                      // the night. Re-checked every minute.
                      final status = ref.watch(martStoreStatusProvider).value ??
                          MartStoreStatus.open;
                      return DeliveryHeader(
                        section: MartHeaderSection.top,
                        campaign: state.activeCampaign,
                        isClosed: !status.isOpen,
                        nextOpeningTimeText: status.nextOpeningTimeText,
                        // The distance-based promise when the backend could work
                        // one out, else the store's own published estimate.
                        deliveryMinutes:
                            status.etaMinutes ?? _deliveryMinutes(state),
                      );
                    },
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedSearchBar(
                    child: DeliveryHeader(
                      section: MartHeaderSection.search,
                      campaign: state.activeCampaign,
                      categories: state.categories,
                      selectedCategoryId: state.selectedCategoryId,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: DeliveryHeader(
                    section: MartHeaderSection.categories,
                    categories: state.categories,
                    campaign: state.activeCampaign,
                    selectedCategoryId: state.selectedCategoryId,
                    // Re-themes the page in place. The header and bottom nav stay put
                    // in the reference too, so pushing a route would only add a
                    // back-stack entry for something that never leaves this screen.
                    onCategoryTap: (catId) =>
                        ref.read(homeProvider.notifier).selectCategory(catId),
                    onAllTap: () =>
                        ref.read(homeProvider.notifier).selectCategory(''),
                  ),
                ),

                // 2. Housefull Sale Banner matching reference design with active theme colors
                SliverToBoxAdapter(
                  child: HousefullSaleBanner(
                    campaign: state.activeCampaign,
                    dealProducts: _dealProducts(state),
                    categories: state.categories,
                    onCrazyDealsTap: () => context.push(
                      RoutePaths.productListing,
                      extra: const ProductListingArgs(title: 'Deal of the day'),
                    ),
                    onCategoryCardTap: (catId) =>
                        context.push(RoutePaths.subCategoryOf(catId)),
                  ),
                ),

                // 3. LOWEST PRICES EVER RAIL (Sorted by lowest price first, matching reference card design)
                SliverToBoxAdapter(
                  child: LowestPricesEverRow(
                    products: _visibleProducts(state),
                    onProductTap: (p) =>
                        context.push(RoutePaths.productDetailsOf(p.id)),
                  ),
                ),

                // 4. BESTSELLERS (Category Collage Cards matching reference design 1:1)
                SliverToBoxAdapter(
                  child: BestsellersRow(
                    categories: state.categories,
                    sections: state.sections,
                    campaigns: state.campaigns,
                    onCategoryTap: (catId) =>
                        context.push(RoutePaths.subCategoryOf(catId)),
                    onSeeAll: () => context.go(RoutePaths.categories),
                  ),
                ),

                // 5. FEATURED THIS WEEK — the admin's promotional banners.
                //
                // This used to be three hand-painted cards ('Newly Launched', 'Price
                // Drop', 'Plum Cakes') with no data behind them at all: invented
                // headlines advertising products that were not in the catalogue, and
                // every tap opened the same generic listing. Meanwhile `topBanners`
                // was fetched from the panel on every load and thrown away. Hidden
                // rather than faked when the admin has uploaded nothing.
                if (state.topBanners.isNotEmpty)
                  SliverToBoxAdapter(
                    child: BannerCarousel(
                      banners: state.topBanners,
                      isLoading: state.isLoadingBanners,
                      onTap: (banner) => _openBanner(context, banner),
                    ),
                  ),

                // 4. SHOP BY CATEGORY (Horizontal category cards with scroll arrow)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 2),
                    child: ShopByCategoryRow(
                      categories: state.categories,
                      isLoading: state.isLoadingCategories,
                      onSeeAll: () => context.go(RoutePaths.categories),
                      onCategoryTap: (catId) =>
                          context.push(RoutePaths.subCategoryOf(catId)),
                    ),
                  ),
                ),

                // 6. ALL CATEGORY SECTIONS (4-Column Grids per category matching reference screenshot 1:1)
                SliverToBoxAdapter(
                  child: AllCategorySectionsFeed(
                    categories: _visibleTree(state),
                    onCategoryTap: (catId) =>
                        context.push(RoutePaths.subCategoryOf(catId)),
                  ),
                ),

                // Sign-off at the end of the feed.
                const SliverToBoxAdapter(
                  child: BrandFooter(
                    wordmark: 'azanto',
                    tagline: 'Fresh essentials, delivered to your doorstep.',
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xl * 2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Sections for the current selection: everything under 'All', otherwise only
  /// the chosen category's.
  ///
  /// Selecting a category must not leave unrelated products on screen — that is
  /// the whole point of the selection.
  List<HomeSection> _visibleSections(HomeState state) {
    if (state.selectedCategoryId.isEmpty) return state.sections;
    return state.sections
        .where((s) => s.categoryId == state.selectedCategoryId)
        .toList();
  }

  List<Product> _visibleProducts(HomeState state) =>
      _visibleSections(state).expand((s) => s.products).toList();

  /// The category tree for the current selection: everything under 'All',
  /// otherwise the chosen category and its own children.
  List<Category> _visibleTree(HomeState state) {
    final selected = state.selectedCategoryId;
    if (selected.isEmpty) return state.allCategories;
    return state.allCategories
        .where((c) => c.id == selected || c.parentId == selected)
        .toList();
  }

  /// The home section that backs "Deal of the day".
  static const _dealSectionId = 'flash';

  /// The delivery estimate to show in the header: the quickest of the stores
  /// serving this address, since that is the one an order would go to.
  int? _deliveryMinutes(HomeState state) {
    final published = state.sellers
        .map((s) => s.deliveryMinutes)
        .whereType<int>()
        .where((m) => m > 0);
    if (published.isEmpty) return null;
    return published.reduce((a, b) => a < b ? a : b);
  }

  List<Product> _dealProducts(HomeState state) {
    for (final section in state.sections) {
      if (section.id == _dealSectionId) return section.products;
    }
    return const [];
  }

  /// Sends a banner tap wherever its CTA link points.
  ///
  /// [PromoBanner] already classifies the admin's free-text link, so the
  /// destination is the admin's decision rather than the widget's. Anything not
  /// pointing at a category opens the listing under the banner's own title,
  /// because a banner that does nothing on tap reads as broken.
  void _openBanner(BuildContext context, PromoBanner banner) {
    final categoryId = banner.targetId;
    if (banner.target == BannerTarget.category && categoryId.isNotEmpty) {
      context.push(RoutePaths.subCategoryOf(categoryId));
      return;
    }
    final title = banner.title.trim();
    context.push(
      RoutePaths.productListing,
      extra: ProductListingArgs(title: title.isEmpty ? 'Offers' : title),
    );
  }
}

/// Pins the Mart search field below the scrolling header.
///
/// Fixed extent: the field is one row of a known height, so min and max are the
/// same and it neither grows nor shrinks as the page moves — which is what
/// keeps it from overlapping the content sliding beneath it.
class _PinnedSearchBar extends SliverPersistentHeaderDelegate {
  const _PinnedSearchBar({required this.child});

  final Widget child;

  /// Search field (48) plus the breathing room the header gave it.
  static const _height = 60.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      SizedBox.expand(child: child);

  @override
  bool shouldRebuild(_PinnedSearchBar old) => old.child != child;
}
