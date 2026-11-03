import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/data/models/restaurant_model.dart';

/// Every restaurant showed "0.0 km".
///
/// The backend attaches `distanceInKm` only when the request carries the user's
/// coordinates, and the listing calls sent none — so the field was absent, the
/// model fell back to 0, and the card hid the chip. The fix supplies the
/// coordinates inside `getRestaurants`, where every listing passes through.
void main() {
  Map<String, dynamic> apiRestaurant(Map<String, dynamic> extra) => {
        '_id': 'r1',
        'name': 'cghv',
        ...extra,
      };

  test('a distance from the server is read, not recomputed', () {
    final r = RestaurantModel.fromApi(apiRestaurant({'distanceInKm': 5.61}));
    expect(r.distanceKm, 5.61);
  });

  test('metres are accepted too, since the geo query reports those', () {
    // $geoNear returns `distanceMeters`; both shapes reach this model.
    final r = RestaurantModel.fromApi(apiRestaurant({'distanceMeters': 2500}));
    expect(r.distanceKm, 2.5);
  });

  test('no distance from the server stays zero so the chip hides', () {
    // The card renders the chip only when distanceKm > 0. Inventing a number
    // here would be worse than showing none: it would be wrong, not missing.
    final r = RestaurantModel.fromApi(apiRestaurant({}));
    expect(r.distanceKm, 0);
  });
}
