import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/restaurant_model.dart';
import '../../../di/restaurant_providers.dart';

/// Backs the "Trending Now" filter screen with a dedicated, backend-ranked
/// fetch (most orders in the trailing window, first) rather than filtering
/// whatever the generic home list happened to return.
final trendingViewModelProvider =
    NotifierProvider<TrendingViewModel, AsyncValue<List<RestaurantModel>>>(() {
  return TrendingViewModel();
});

class TrendingViewModel extends Notifier<AsyncValue<List<RestaurantModel>>> {
  @override
  AsyncValue<List<RestaurantModel>> build() {
    Future.microtask(() => load());
    return const AsyncValue.loading();
  }

  Future<void> load({bool isRefresh = false}) async {
    if (!isRefresh) state = const AsyncValue.loading();

    final result = await ref.read(restaurantRepositoryProvider).getTrendingRestaurants();
    state = result.isSuccess
        ? AsyncValue.data(result.data ?? const [])
        : AsyncValue.error(result.message ?? 'Failed to load trending restaurants.', StackTrace.current);
  }
}
