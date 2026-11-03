import '../../core/error/failures.dart';
import '../../core/network/api_response.dart';
import '../../domain/repository/restaurant_repository.dart';
import '../datasources/catalog_remote_datasource.dart';
import '../models/category_model.dart';
import '../models/food_model.dart';
import '../models/restaurant_model.dart';

/// Backend-backed catalog repository.
///
/// [zoneIdProvider] is a callback rather than a value so every call picks up
/// the zone detected after location permission, without this repository being
/// rebuilt or holding a stale id.
class RestaurantRepositoryImpl implements RestaurantRepository {
  final CatalogRemoteDataSource _remote;
  final String? Function() _zoneId;

  const RestaurantRepositoryImpl(this._remote, this._zoneId);

  @override
  Future<ApiResponse<List<CategoryModel>>> getCategories({void Function(List<CategoryModel>)? onCache}) =>
      _guard(() => _remote.getCategories(zoneId: _zoneId(), onCache: onCache));

  @override
  Future<ApiResponse<List<RestaurantModel>>> getTrendingRestaurants() =>
      _guard(() => _remote.getRestaurants(zoneId: _zoneId(), sortBy: 'trending', limit: 20));

  /// `radiusKm` alone is enough to put the backend on its $geoNear path
  /// (`wantsGeo` in listApprovedRestaurantsScoped), which is what actually
  /// computes `distanceKm` per restaurant — omitting it silently returns
  /// zone-wide results with every distance reading 0. `sortBy: 'nearest'`
  /// on top orders that geo result by distance instead of its default.
  /// Coordinates are not passed explicitly: the datasource resolves them the
  /// same way every other list on this screen does (selected delivery
  /// address, falling back to live GPS) via its own userCoords lookup.
  @override
  Future<ApiResponse<List<RestaurantModel>>> getNearFastRestaurants() =>
      _guard(() => _remote.getRestaurants(
            zoneId: _zoneId(),
            sortBy: 'nearest',
            radiusKm: 10,
            limit: 50,
          ));

  @override
  Future<ApiResponse<List<RestaurantModel>>> getPopularRestaurants({void Function(List<RestaurantModel>)? onCache}) =>
      _guard(() => _remote.getRestaurants(zoneId: _zoneId(), limit: 50, onCache: onCache));

  @override
  Future<ApiResponse<List<FoodModel>>> getRestaurantMenu(String restaurantId) =>
      _guard(() => _remote.getRestaurantMenu(restaurantId));

  @override
  Future<ApiResponse<List<FoodModel>>> getPopularFoods({void Function(List<FoodModel>)? onCache}) =>
      _guard(() => _remote.getPublicFoods(zoneId: _zoneId(), onCache: onCache));

  /// The ₹99 rail — returns only foods where final selling price <= 99
  @override
  Future<ApiResponse<List<FoodModel>>> getBestOffers({void Function(List<FoodModel>)? onCache}) =>
      _guard(() async {
        bool eligible(FoodModel f) => f.price <= 99.0;
        final foods = await _remote.getPublicFoods(
          zoneId: _zoneId(),
          promo: 'switch99',
          onCache: onCache == null ? null : (cached) => onCache(cached.where(eligible).toList()),
        );
        return foods.where(eligible).toList();
      });

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
