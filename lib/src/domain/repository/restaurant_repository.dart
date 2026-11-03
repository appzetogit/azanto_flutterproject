import '../../core/network/api_response.dart';
import '../../data/models/restaurant_model.dart';
import '../../data/models/category_model.dart';
import '../../data/models/food_model.dart';

abstract class RestaurantRepository {
  /// [onCache], where supported, fires synchronously with a cached copy (if
  /// any) before the network call resolves — lets a caller paint instantly
  /// and then replace with the live result.
  Future<ApiResponse<List<CategoryModel>>> getCategories({void Function(List<CategoryModel>)? onCache});
  /// Restaurants ranked by order volume in the trailing window, most first —
  /// backs the "Trending Now" filter.
  Future<ApiResponse<List<RestaurantModel>>> getTrendingRestaurants();
  /// Restaurants within 10km of the user, nearest first — backs the
  /// "Near & Fast" filter.
  Future<ApiResponse<List<RestaurantModel>>> getNearFastRestaurants();
  Future<ApiResponse<List<RestaurantModel>>> getPopularRestaurants({void Function(List<RestaurantModel>)? onCache});
  Future<ApiResponse<List<FoodModel>>> getRestaurantMenu(String restaurantId);
  Future<ApiResponse<List<FoodModel>>> getPopularFoods({void Function(List<FoodModel>)? onCache});
  Future<ApiResponse<List<FoodModel>>> getBestOffers({void Function(List<FoodModel>)? onCache});
}
