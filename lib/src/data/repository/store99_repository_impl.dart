import '../../core/error/failures.dart';
import '../../core/network/api_response.dart';
import '../../domain/model/store99_brand.dart';
import '../../domain/model/store99_cuisine.dart';
import '../../domain/model/store99_product.dart';
import '../../domain/repository/store99_repository.dart';
import '../datasources/catalog_remote_datasource.dart';
import '../models/food_model.dart';
import '../models/restaurant_model.dart';

/// Backend-backed 99 Store.
///
/// The backend models this as the `switch99` promo slug on the cross-restaurant
/// food feed rather than a price filter, so nothing here filters on price.
/// Cuisines come from the real category list and brands from the restaurant
/// list — there are no dedicated 99-Store endpoints.
class Store99RepositoryImpl implements Store99Repository {
  final CatalogRemoteDataSource _remote;
  final String? Function() _zoneId;

  const Store99RepositoryImpl(this._remote, this._zoneId);

  /// Deliberately NOT sending `promo=switch99`.
  ///
  /// That server-side promo keeps anything whose price STRING contains "99" —
  /// ₹199, ₹299, ₹990 — which is not what this screen means. Intersected with
  /// the real rule below it left one dish in the whole catalogue, and nothing
  /// at all once a cuisine was chosen.
  ///
  /// The rule that matters is `price <= 99`, applied here, which is also what
  /// the screen promises: "meals at ₹99 or less".
  static const _under99 = 99.0;

  /// Fetch wide, then narrow: the ≤99 items are a minority of the catalogue, so
  /// a small page would filter down to almost nothing.
  static const _fetchLimit = 500;

  @override
  Future<ApiResponse<List<Store99Cuisine>>> getCuisines() {
    return _guard(() async {
      final categories = await _remote.getCategories(zoneId: _zoneId());
      return [
        const Store99Cuisine(id: 'all', label: 'All', imagesPath: ''),
        ...categories.map(
          (c) => Store99Cuisine(
            id: c.id,
            label: c.name,
            imagesPath: c.imageUrl,
            // The filter is a keyword match, so the name is what finds dishes.
            slug: c.name,
          ),
        ),
      ];
    });
  }

  @override
  Future<ApiResponse<List<Store99Brand>>> getBrands() {
    return _guard(() async {
      final restaurants = await _remote.getRestaurants(zoneId: _zoneId(), limit: 12);
      return restaurants
          .map((r) => Store99Brand(id: r.id, label: r.name, imageUrl: r.imageUrl))
          .toList();
    });
  }



  @override
  Future<ApiResponse<List<Store99Product>>> getTrendingDishes({
    String cuisineId = 'all',
  }) {
    return _guard(() async {
      // Cuisine-scoped like the explore grid. Selecting 'Idli' used to leave
      // this row showing pizza and dosa, so the screen contradicted the chip
      // the shopper had just tapped.
      final foods = await _remote.getPublicFoods(
        zoneId: _zoneId(),
        categorySlug: cuisineId == 'all' ? null : cuisineId,
        limit: _fetchLimit,
      );
      return foods
          .where((f) => f.price <= _under99)
          .map(_toProduct)
          .toList();
    });
  }

  @override
  Future<ApiResponse<List<Store99Product>>> getExploreProducts({
    String cuisineId = 'all',
    int page = 1,
    int limit = 10,
  }) {
    return _guard(() async {
      final foods = await _remote.getPublicFoods(
        zoneId: _zoneId(),
        categorySlug: cuisineId == 'all' ? null : cuisineId,
        limit: _fetchLimit,
      );

      final eligibleFoods =
          foods.where((f) => f.price <= _under99).toList();

      // Client-side pagination windowing applied on eligible (<= 99) products
      final start = (page - 1) * limit;
      if (start >= eligibleFoods.length) return const <Store99Product>[];
      return eligibleFoods
          .sublist(start, (start + limit).clamp(0, eligibleFoods.length))
          .map(_toProduct)
          .toList();
    });
  }

  @override
  Future<ApiResponse<RestaurantModel?>> getRestaurantForProduct(String restaurantId) =>
      _guard(() => _remote.getRestaurantById(restaurantId));

  Store99Product _toProduct(FoodModel f) {
    return Store99Product(
      id: f.id,
      restaurantId: f.restaurantId,
      restaurantName: '',
      name: f.name,
      description: f.description,
      price: f.price,
      originalPrice: f.originalPrice,
      imageUrl: f.imageUrl,
      rating: f.rating,
      ratingCount: f.reviewCount,
      deliveryTime: f.deliveryTime,
      isVeg: f.isVeg,
    );
  }

  Future<ApiResponse<T>> _guard<T>(Future<T> Function() run) async {
    try {
      return ApiResponse.success(await run());
    } on Failure catch (f) {
      return ApiResponse<T>.error(f.message);
    } catch (_) {
      return ApiResponse<T>.error('Something went wrong. Please try again.');
    }
  }
}
