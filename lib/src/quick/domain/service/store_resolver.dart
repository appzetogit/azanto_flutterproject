import '../model/seller.dart';

/// Picks which of the company's outlets serves the customer.
///
/// Quick Commerce is one company running several outlets, not a marketplace of
/// independent merchants, so the customer never chooses who fulfils an order —
/// the app does, from location. The backend already returns `distanceInKm`,
/// `isAcceptingOrders` and opening state per outlet, so this is a ranking over
/// real data: nothing about the serving outlet is hardcoded.
///
/// One outlet per order is a backend invariant (`Order.restaurantId` is
/// `required`), so there is always exactly one answer — which is also how
/// Blinkit-style operations actually work. The difference from a marketplace is
/// that the choice is made *for* the customer and stays out of the way.
abstract final class StoreResolver {
  /// The outlet that should serve this basket, or null when none can.
  ///
  /// Prefers open outlets: a nearer outlet that is closed cannot fulfil
  /// anything, so it must not win over an open one further away. Among equals,
  /// nearest wins. Outlets with no distance (backend omitted it, e.g. the
  /// customer has not set a location yet) sort last rather than first — an
  /// unknown distance is not a good distance.
  static Seller? serving(List<Seller> outlets, {double? maxDistanceKm}) {
    final candidates = outlets.where((o) {
      if (!o.acceptingOrders) return false;
      final km = o.distanceKm;
      if (maxDistanceKm != null && km != null && km > maxDistanceKm) return false;
      return true;
    }).toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final ad = a.distanceKm ?? double.infinity;
      final bd = b.distanceKm ?? double.infinity;
      return ad.compareTo(bd);
    });
    return candidates.first;
  }

  /// Outlets worth showing under "Nearby stores", nearest first.
  ///
  /// Closed outlets are kept (a customer may want to know one exists nearby and
  /// when it opens) but always sort after open ones.
  static List<Seller> nearby(List<Seller> outlets, {double? maxDistanceKm}) {
    final visible = outlets.where((o) {
      final km = o.distanceKm;
      return maxDistanceKm == null || km == null || km <= maxDistanceKm;
    }).toList();

    visible.sort((a, b) {
      if (a.acceptingOrders != b.acceptingOrders) {
        return a.acceptingOrders ? -1 : 1;
      }
      final ad = a.distanceKm ?? double.infinity;
      final bd = b.distanceKm ?? double.infinity;
      return ad.compareTo(bd);
    });
    return visible;
  }
}
