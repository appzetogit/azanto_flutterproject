import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/restaurant_model.dart';
import '../../../di/restaurant_providers.dart';

/// Backs the "Near & Fast" filter screen with a dedicated fetch — restaurants
/// within 10km of the user, nearest first — rather than filtering whatever
/// the generic home list happened to return (which never carries a real
/// distance: it fetches zone-wide with no radius, so every restaurant's
/// distance reads 0).
final nearFastViewModelProvider =
    NotifierProvider<NearFastViewModel, AsyncValue<List<RestaurantModel>>>(() {
  return NearFastViewModel();
});

class NearFastViewModel extends Notifier<AsyncValue<List<RestaurantModel>>> {
  @override
  AsyncValue<List<RestaurantModel>> build() {
    Future.microtask(() => load());
    return const AsyncValue.loading();
  }

  Future<void> load({bool isRefresh = false}) async {
    if (!isRefresh) state = const AsyncValue.loading();

    final result = await ref.read(restaurantRepositoryProvider).getNearFastRestaurants();
    state = result.isSuccess
        ? AsyncValue.data(result.data ?? const [])
        : AsyncValue.error(result.message ?? 'Failed to load nearby restaurants.', StackTrace.current);
  }
}
