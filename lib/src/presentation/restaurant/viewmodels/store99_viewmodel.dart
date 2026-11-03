import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../di/store99_providers.dart';
import '../../../domain/model/store99_cuisine.dart';
import '../../../domain/service/store99_service.dart';
import 'store99_state.dart';

final store99ViewModelProvider =
    NotifierProvider<Store99ViewModel, Store99State>(() {
  return Store99ViewModel();
});

class Store99ViewModel extends Notifier<Store99State> {
  late Store99Service _service;
  static const int _pageSize = 6;

  /// The chip the user last picked, kept across app restarts. Every selection
  /// writes it, so it is the source of truth for what to restore.
  static const String _selectedCuisineKey = 'store99_selected_cuisine';

  @override
  Store99State build() {
    _service = ref.watch(store99ServiceProvider);
    // Initialize data asynchronously
    Future.microtask(() => loadInitialData());
    return const Store99State(isLoading: true);
  }

  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final cuisinesResp = await _service.getCuisines();
      final cuisines = cuisinesResp.data ?? const <Store99Cuisine>[];

      // A cold start builds this notifier at 'all', so the chip has to come
      // back from disk before anything is fetched for it — otherwise the two
      // rows below load the default cuisine and the screen has already reset.
      final restored = await _restoreSelectedCuisineId(cuisines);

      final brandsResp = await _service.getBrands();
      // Resolved against the list just fetched, not state.cuisines: that is
      // still empty on the first load, which silently sent 'all'.
      final slug = _slugFor(restored, cuisines);
      final trendingResp = await _service.getTrendingDishes(cuisineId: slug);
      final exploreResp = await _service.fetchProductsPage(
        cuisineId: slug,
        page: 1,
        limit: _pageSize,
      );

      final brands = brandsResp.data ?? const [];
      final trending = trendingResp.data ?? const [];
      final explore = exploreResp.data ?? const [];

      state = state.copyWith(
        cuisines: cuisines,
        brands: brands,
        trendingDishes: trending,
        exploreDishes: explore,
        selectedCuisineId: restored,
        page: 1,
        hasMore: explore.length >= _pageSize,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load 99 Store products. Please try again.',
      );
    }
  }

  /// The saved chip, or 'all' when nothing was saved or the saved category is
  /// no longer in the catalogue — a stale id would select a chip that is not
  /// on screen and filter everything away.
  Future<String> _restoreSelectedCuisineId(List<Store99Cuisine> cuisines) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_selectedCuisineKey);
      if (saved == null || saved.isEmpty) return 'all';
      if (saved == 'all' || cuisines.any((c) => c.id == saved)) return saved;
      await prefs.remove(_selectedCuisineKey);
    } catch (_) {
      // Storage is a convenience here; losing it just means the default chip.
    }
    return 'all';
  }

  Future<void> _persistSelectedCuisineId(String cuisineId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedCuisineKey, cuisineId);
    } catch (_) {
      // Ignored for the same reason as above.
    }
  }

  /// The keyword the catalogue filter matches for the selected chip.
  ///
  /// The chip's id is a category ObjectId; the filter regex-matches names, so
  /// sending the id found nothing and every category came back empty.
  String _slugFor(String id, List<Store99Cuisine> cuisines) {
    if (id.isEmpty || id == 'all') return 'all';
    for (final c in cuisines) {
      if (c.id == id) return c.slug.isNotEmpty ? c.slug : c.label;
    }
    return 'all';
  }

  String get _selectedSlug => _slugFor(state.selectedCuisineId, state.cuisines);

  Future<void> selectCuisine(String cuisineId) async {
    if (state.selectedCuisineId == cuisineId) return;

    _persistSelectedCuisineId(cuisineId);
    state = state.copyWith(
      selectedCuisineId: cuisineId,
      isLoading: true,
      page: 1,
      hasMore: true,
    );

    try {
      final slug = _selectedSlug;
      final exploreResp = await _service.fetchProductsPage(
        cuisineId: slug,
        page: 1,
        limit: _pageSize,
      );
      // Both rows move together: the trending strip showing another cuisine
      // beside a selected chip is the contradiction this screen had.
      final trendingResp = await _service.getTrendingDishes(cuisineId: slug);

      final explore = exploreResp.data ?? const [];

      state = state.copyWith(
        exploreDishes: explore,
        trendingDishes: trendingResp.data ?? const [],
        page: 1,
        hasMore: explore.length >= _pageSize,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to filter by cuisine.',
      );
    }
  }

  Future<void> loadMoreProducts() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await _service.fetchProductsPage(
        cuisineId: _selectedSlug,
        page: nextPage,
        limit: _pageSize,
      );

      final newProducts = response.data ?? const [];

      if (newProducts.isEmpty) {
        state = state.copyWith(
          isLoadingMore: false,
          hasMore: false,
        );
      } else {
        state = state.copyWith(
          exploreDishes: [...state.exploreDishes, ...newProducts],
          page: nextPage,
          hasMore: newProducts.length >= _pageSize,
          isLoadingMore: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<RestaurantModel?> getRestaurantForProduct(String restaurantId) async {
    return await _service.findRestaurant(restaurantId);
  }
}
