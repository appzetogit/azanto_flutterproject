import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/utils/logger.dart';
import '../../../di/repository_providers.dart';
import '../../../di/service_providers.dart';
import '../../../domain/model/order.dart';
import '../../../domain/model/product.dart';
import 'home_state.dart';
import '../../../di/zone_providers.dart';

/// Builds the home screen from the real catalog.
///
/// Sections are derived rather than fetched: the backend has no
/// "trending"/"best sellers" endpoints, so `CatalogGroupingService` ranks a
/// fetched catalog page. Documented in README → Backend Gaps.
class HomeController extends Notifier<HomeState> {
  @override
  HomeState build() {
    // Rebuilds when the shopper's zone resolves or changes, so the whole feed
    // re-fetches for the new zone. Mart stock is zone-scoped: without this the
    // page would keep showing another zone's catalogue after a change of
    // address until the app was restarted.
    ref.watch(martZoneIdProvider);
    Future.microtask(load);
    return const HomeState();
  }

  Future<void> load({bool refresh = false}) async {
    if (refresh) state = state.copyWith(isRefreshing: true, clearFailure: true);

    // Banners, categories and the catalog load in parallel; each updates the
    // UI as it lands so no section waits on another.
    await Future.wait([
      _loadBanners(),
      _loadCoupons(),
      _loadCatalog(),
    ]);

    if (refresh) state = state.copyWith(isRefreshing: false);
  }

  Future<void> _loadBanners() async {
    state = state.copyWith(isLoadingBanners: true);
    try {
      final content = ref.read(catalogContentRepositoryProvider);
      // Same three calls as before — only where each collection lands has
      // changed. Hero backs the header; top is the strip below Nearby stores;
      // home-promotion rides along with hero because it has no slot of its own
      // and dropping it would silently unpublish whatever the admin set there.
      final results = await Future.wait([
        content.heroBanners(),
        content.topBanners(),
        content.promotionBanners(),
      ]);
      final hero = [...results[0], ...results[2]];
      final top = results[1];
      AppLogger.debug(
        'home banners: ${results[0].length} hero + ${results[2].length} '
        'promotion = ${hero.length} in header, ${top.length} in the strip',
        scope: 'banners',
      );
      // Fetched alongside the banners because it is the same kind of
      // admin-managed merchandising, and it fails the same way: null just means
      // no promotion is scheduled.
      final campaigns = await content.martSaleCampaigns();
      state = state.copyWith(
        heroBanners: hero,
        topBanners: top,
        campaigns: campaigns,
        isLoadingBanners: false,
      );
    } catch (e, stack) {
      // Banners are decoration; their failure must not take the page down —
      // but it must not be silent either.
      AppLogger.error('home banners failed to load', error: e, stackTrace: stack);
      state = state.copyWith(isLoadingBanners: false);
    }
  }

  Future<void> _loadCoupons() async {
    state = state.copyWith(isLoadingCoupons: true);
    try {
      final coupons = await ref.read(couponRepositoryProvider).available();
      state = state.copyWith(
        // Expired offers are still returned by the endpoint; never show them.
        coupons: coupons.where((c) => !c.isExpired).toList(),
        isLoadingCoupons: false,
      );
    } catch (_) {
      // Offers are promotional; their failure must not take the page down.
      state = state.copyWith(isLoadingCoupons: false);
    }
  }

  static const _catalogPageSize = 50;

  /// These pages are fetched one after another, so each one is a round trip the
  /// user waits through before the first row paints. They only feed the derived
  /// rankings (flash sale / best sellers / recommended), and those are stable
  /// well before 150 items — ten pages cost eight extra serial requests and
  /// changed the top twelve of each row by nothing.
  static const _maxCatalogPages = 3;

  static const _maxCategoryRows = 20;

  Future<void> _loadCatalog() async {
    state = state.copyWith(
      isLoadingCategories: true,
      isLoadingSections: true,
      clearFailure: true,
    );

    try {
      // One request for the whole tree: `topLevel()` fetches the same flat list
      // and throws the children away, so asking for both would double the call.
      final allCategories = await ref.read(categoryRepositoryProvider).all();
      final categories = allCategories.where((c) => c.isCore).toList();
      state = state.copyWith(
        categories: categories,
        allCategories: allCategories,
        isLoadingCategories: false,
      );

      final products = ref.read(productRepositoryProvider);
      final grouping = ref.read(catalogGroupingServiceProvider);

      // Every home section is ranked from this list, so a single page meant the
      // rankings only ever saw the first 50 items in the catalogue.
      var catalog = await products.list(pageSize: _catalogPageSize);
      var all = catalog.items;
      while (catalog.hasMore && catalog.page < _maxCatalogPages) {
        catalog = await products.list(
          page: catalog.page + 1,
          pageSize: _catalogPageSize,
        );
        all = [...all, ...catalog.items];
      }

      // One request per category the backend returned, in parallel — every
      // category gets a row, not just the first eight. Capped only so an admin
      // adding fifty categories cannot fire fifty requests at once.
      final rowCategories = categories.take(_maxCategoryRows).toList();
      final rows = await Future.wait(
        rowCategories.map(
          (c) => products
              .list(categoryId: c.id, pageSize: 12)
              .then((page) => grouping.distinctByName(page.items))
              .catchError((_) => <Product>[]),
        ),
      );

      final sections = <HomeSection>[
        HomeSection(
          id: 'flash',
          title: 'Flash sale',
          subtitle: 'Deepest discounts, while stock lasts',
          products: grouping.flashSale(all),
        ),
        HomeSection(
          id: 'trending',
          title: 'Trending near you',
          products: grouping
              .distinctByName(all.where((p) => p.ratingCount > 0).toList())
              .take(12)
              .toList(),
        ),
        HomeSection(
          id: 'recently-bought',
          title: 'Buy it again',
          subtitle: 'From your recent orders',
          products: await _recentlyBought(all),
        ),
        HomeSection(
          id: 'recommended',
          title: 'Recommended for you',
          products: grouping.recommended(all),
        ),
        HomeSection(
          id: 'best-sellers',
          title: 'Best sellers',
          products: grouping.bestSellers(all),
          showRanks: true,
        ),
        for (var i = 0; i < rowCategories.length; i++)
          HomeSection(
            id: 'category-${rowCategories[i].id}',
            title: rowCategories[i].name,
            products: rows[i],
            categoryId: rowCategories[i].id,
          ),
      ]..removeWhere((s) => s.isEmpty);

      // Sellers come from the backend's own list, not from whatever products
      // happen to be in the catalogue: a store that has not published products
      // yet still exists and should be shown. The derived list is the fallback,
      // because it carries per-seller product previews the list endpoint has no
      // way to return.
      final derived = grouping.sellersFrom(all);
      var sellers = derived;
      try {
        final listed = await products.sellers();
        if (listed.isNotEmpty) {
          final byId = {for (final s in derived) s.id: s};
          // Prefer the backend row, but keep the product preview when we have
          // one for that seller.
          sellers = [
            for (final s in listed)
              byId[s.id] == null
                  ? s
                  : s.copyWith(
                      products: byId[s.id]!.products,
                      productCount: byId[s.id]!.productCount,
                    ),
          ];
        }
      } catch (e) {
        AppLogger.debug('seller list failed, using derived: $e', scope: 'quick.home');
      }

      AppLogger.debug(
        'home: ${categories.length} categories, ${all.length} products, '
        '${sellers.length} sellers, ${sections.length} sections',
        scope: 'quick.home',
      );

      state = state.copyWith(
        sections: sections,
        brands: grouping.brandsFrom(all).take(12).toList(),
        sellers: sellers,
        isLoadingSections: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingCategories: false,
        isLoadingSections: false,
        failure: ErrorMapper.toFailure(e),
      );
    }
  }

  /// Products from the customer's own delivered orders, matched back to the
  /// live catalog so prices and stock are current.
  Future<List<Product>> _recentlyBought(List<Product> catalog) async {
    try {
      final orders = await ref.read(orderRepositoryProvider).list(pageSize: 10);
      final boughtIds = <String>{};
      for (final Order order in orders.items) {
        for (final line in order.lines) {
          boughtIds.add(line.itemId);
        }
      }
      return catalog.where((p) => boughtIds.contains(p.id)).take(12).toList();
    } catch (_) {
      // Signed-out or failed: the section simply does not render.
      return const [];
    }
  }


  /// Selects a header category, re-theming the page from that category's
  /// campaign. Purely local: every campaign was fetched up front, so the
  /// transition needs no request.
  void selectCategory(String categoryId) {
    if (state.selectedCategoryId == categoryId) return;
    state = state.copyWith(selectedCategoryId: categoryId);
  }
}

final homeProvider = NotifierProvider<HomeController, HomeState>(HomeController.new);
