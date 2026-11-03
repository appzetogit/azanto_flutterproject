import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/diag_log.dart';
import '../../../di/restaurant_providers.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../data/models/food_model.dart';
import '../../../domain/repository/restaurant_repository.dart';
import '../../../shared/address/global_address.dart';
import 'banners_viewmodel.dart';
import 'zone_viewmodel.dart';

class HomeState {
  final AsyncValue<List<CategoryModel>> categories;
  final AsyncValue<List<FoodModel>> popularFoods;
  final AsyncValue<List<FoodModel>> bestOffers;
  final AsyncValue<List<RestaurantModel>> nearbyRestaurants;

  HomeState({
    required this.categories,
    required this.popularFoods,
    required this.bestOffers,
    required this.nearbyRestaurants,
  });

  HomeState copyWith({
    AsyncValue<List<CategoryModel>>? categories,
    AsyncValue<List<FoodModel>>? popularFoods,
    AsyncValue<List<FoodModel>>? bestOffers,
    AsyncValue<List<RestaurantModel>>? nearbyRestaurants,
  }) {
    return HomeState(
      categories: categories ?? this.categories,
      popularFoods: popularFoods ?? this.popularFoods,
      bestOffers: bestOffers ?? this.bestOffers,
      nearbyRestaurants: nearbyRestaurants ?? this.nearbyRestaurants,
    );
  }
}

final homeViewModelProvider = NotifierProvider<HomeViewModel, HomeState>(() {
  return HomeViewModel();
});

class HomeViewModel extends Notifier<HomeState> {
  late RestaurantRepository _repository;

  // Bumped at the start of every loadHomeData() call. The cold-start call
  // fires before zone detection resolves and goes out unscoped; the listener
  // below re-runs once the zone arrives — but that first call is still
  // in-flight and can finish LAST (it's a heavier unscoped fetch), clobbering
  // the correctly-scoped result with stale nationwide data. Only the call
  // that is still the most-recently-started by the time it resolves may
  // commit its result.
  int _generation = 0;

  @override
  HomeState build() {
    _repository = ref.watch(restaurantRepositoryProvider);
    // Re-scope the home rails once the location/zone resolves (or changes).
    ref.listen(globalSelectedAddressProvider, (previous, next) {
      if (previous != next) {
        ref.invalidate(promoBannersProvider);
        ref.invalidate(heroBannersProvider);
        ref.invalidate(store99BannersProvider);
        unawaited(loadHomeData(isRefresh: true, retryZone: true));
      }
    });
    ref.listen(catalogZoneIdProvider, (previous, next) {
      unawaited(diagLog('home: catalogZoneIdProvider listener previous=$previous next=$next'));
      unawaited(loadHomeData(isRefresh: true));
    });
    unawaited(diagLog('home: build() initial zoneId=${ref.read(catalogZoneIdProvider)}'));
    Future.microtask(() => loadHomeData());
    return HomeState(
      categories: const AsyncValue.loading(),
      popularFoods: const AsyncValue.loading(),
      bestOffers: const AsyncValue.loading(),
      nearbyRestaurants: const AsyncValue.loading(),
    );
  }

  /// [retryZone]: pull-to-refresh only. If the zone is still unresolved
  /// (a transient GPS failure with nothing to fall back on, or a
  /// `getLastKnownPosition()` miss right after install/reboot), re-run
  /// detection before reloading — otherwise a shopper stuck on the
  /// nationwide-unscoped list has no way back short of killing the app,
  /// since [catalogZoneIdProvider] only re-fires this when its value
  /// actually *changes*, and a failed detection never changes.
  Future<void> loadHomeData({bool isRefresh = false, bool retryZone = false}) async {
    if (retryZone && ref.read(currentZoneIdProvider) == null) {
      await ref.read(zoneViewModelProvider.notifier).refresh();
    }

    final generation = ++_generation;
    await diagLog('home: loadHomeData gen=$generation isRefresh=$isRefresh zoneId=${ref.read(catalogZoneIdProvider)}');
    if (!isRefresh) {
      state = state.copyWith(
        categories: const AsyncValue.loading(),
        popularFoods: const AsyncValue.loading(),
        bestOffers: const AsyncValue.loading(),
        nearbyRestaurants: const AsyncValue.loading(),
      );
    }

    // Each onCache fires synchronously, right here, with whatever's still
    // cached from the last fetch — paints the screen instantly instead of a
    // spinner, and gets overwritten below once the live response lands.
    final responses = await Future.wait([
      _repository.getCategories(
        onCache: (c) {
          if (generation != _generation) return;
          state = state.copyWith(categories: AsyncValue.data(c));
        },
      ),
      _repository.getPopularFoods(
        onCache: (f) {
          if (generation != _generation) return;
          state = state.copyWith(popularFoods: AsyncValue.data(f));
        },
      ),
      _repository.getBestOffers(
        onCache: (f) {
          if (generation != _generation) return;
          state = state.copyWith(bestOffers: AsyncValue.data(f));
        },
      ),
      _repository.getPopularRestaurants(
        onCache: (r) {
          if (generation != _generation) return;
          state = state.copyWith(nearbyRestaurants: AsyncValue.data(r));
        },
      ), // mapping popular to nearby
    ]);

    // A newer loadHomeData() has started since this one began — its result
    // (or the one still in flight) is more current, so don't stomp on it.
    if (generation != _generation) return;

    final categoriesRes = responses[0] as dynamic;
    final popularFoodsRes = responses[1] as dynamic;
    final bestOffersRes = responses[2] as dynamic;
    final nearbyRes = responses[3] as dynamic;

    await diagLog(
      'home: gen=$generation committed nearbyRes.isSuccess=${nearbyRes.isSuccess} '
      'count=${nearbyRes.isSuccess ? (nearbyRes.data as List).length : nearbyRes.message}',
    );

    state = state.copyWith(
      categories: categoriesRes.isSuccess
          ? AsyncValue.data(categoriesRes.data)
          : AsyncValue.error(categoriesRes.message, StackTrace.current),
      popularFoods: popularFoodsRes.isSuccess
          ? AsyncValue.data(popularFoodsRes.data)
          : AsyncValue.error(popularFoodsRes.message, StackTrace.current),
      bestOffers: bestOffersRes.isSuccess
          ? AsyncValue.data(bestOffersRes.data)
          : AsyncValue.error(bestOffersRes.message, StackTrace.current),
      nearbyRestaurants: nearbyRes.isSuccess
          ? AsyncValue.data(nearbyRes.data)
          : AsyncValue.error(nearbyRes.message, StackTrace.current),
    );
  }
}
