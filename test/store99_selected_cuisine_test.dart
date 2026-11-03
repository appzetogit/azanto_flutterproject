import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/core/network/api_response.dart';
import 'package:azanto/src/data/models/restaurant_model.dart';
import 'package:azanto/src/di/store99_providers.dart';
import 'package:azanto/src/domain/model/store99_brand.dart';
import 'package:azanto/src/domain/model/store99_cuisine.dart';
import 'package:azanto/src/domain/model/store99_product.dart';
import 'package:azanto/src/domain/repository/store99_repository.dart';
import 'package:azanto/src/presentation/restaurant/viewmodels/store99_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Picking Soup and restarting the app used to land back on the default chip:
/// the notifier rebuilt at 'all' with nothing saved, and even when the chip was
/// still selected the first load resolved its slug against `state.cuisines`,
/// which is empty until that same load finishes — so every restart quietly
/// fetched the default cuisine.
const _cuisines = [
  Store99Cuisine(id: 'c1', label: 'Biryani', imagesPath: '', slug: 'biryani'),
  Store99Cuisine(id: 'c2', label: 'Soup', imagesPath: '', slug: 'soup'),
];

class _FakeRepo implements Store99Repository {
  /// Every cuisine slug the screen asked the backend for, in order.
  final List<String> requested = [];

  @override
  Future<ApiResponse<List<Store99Cuisine>>> getCuisines() async =>
      ApiResponse.success(_cuisines);

  @override
  Future<ApiResponse<List<Store99Brand>>> getBrands() async =>
      ApiResponse.success(const []);

  @override
  Future<ApiResponse<List<Store99Product>>> getTrendingDishes({
    String cuisineId = 'all',
  }) async {
    requested.add(cuisineId);
    return ApiResponse.success(const []);
  }

  @override
  Future<ApiResponse<List<Store99Product>>> getExploreProducts({
    String cuisineId = 'all',
    int page = 1,
    int limit = 10,
  }) async {
    requested.add(cuisineId);
    return ApiResponse.success(const []);
  }

  @override
  Future<ApiResponse<RestaurantModel?>> getRestaurantForProduct(String id) async =>
      ApiResponse.success(null);
}

/// A fresh app start: a new container, as a relaunch would build.
Future<(ProviderContainer, _FakeRepo)> _launch() async {
  final repo = _FakeRepo();
  final container = ProviderContainer(
    overrides: [store99RepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  container.listen(store99ViewModelProvider, (_, _) {});
  // The notifier kicks its first load off in a microtask.
  await Future<void>.delayed(Duration.zero);
  return (container, repo);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the chosen cuisine survives a relaunch, and its products load', () async {
    final (first, _) = await _launch();
    await first.read(store99ViewModelProvider.notifier).selectCuisine('c2');
    expect(first.read(store99ViewModelProvider).selectedCuisineId, 'c2');

    final (second, repo) = await _launch();
    expect(second.read(store99ViewModelProvider).selectedCuisineId, 'c2');
    // Not just the chip: the rows have to be Soup's, which means the slug was
    // resolved against the cuisines fetched by this very load.
    expect(repo.requested, everyElement('soup'));
  });

  test('a cuisine that has left the catalogue falls back to the default', () async {
    SharedPreferences.setMockInitialValues({
      'store99_selected_cuisine': 'deleted-category',
    });

    final (container, repo) = await _launch();
    expect(container.read(store99ViewModelProvider).selectedCuisineId, 'all');
    expect(repo.requested, everyElement('all'));
  });

  test('going back to All is saved too', () async {
    final (first, _) = await _launch();
    await first.read(store99ViewModelProvider.notifier).selectCuisine('c2');
    await first.read(store99ViewModelProvider.notifier).selectCuisine('all');

    final (second, _) = await _launch();
    expect(second.read(store99ViewModelProvider).selectedCuisineId, 'all');
  });
}
