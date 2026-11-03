import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/zone_model.dart';
import '../../presentation/home/viewmodels/user_location_provider.dart';
import '../../presentation/home/viewmodels/zone_viewmodel.dart';
import '../data/repository_impl/api_paths.dart';
import 'app_providers.dart';
import 'repository_providers.dart';

/// The delivery zone serving the user's selected address.
///
/// Mart is zone-scoped: a store belongs to a zone, and a shopper must only ever
/// see stock from stores that serve where they are. The zone is resolved from
/// the address's own coordinates by the backend's polygon test, so the app
/// never decides which zone a point falls in — it only reports the point.
///
/// Null means "not known yet": no address selected, no coordinates on it, or
/// the lookup failed — as opposed to a resolved [ZoneModel] whose status is
/// `OUT_OF_SERVICE`, which is a definite answer, not an unknown one. Losing
/// that distinction (this used to collapse both to null) is what let an
/// out-of-coverage address still see the full nationwide catalogue: the
/// repositories below read null as "send no zone filter" either way, so
/// "not known yet" and "definitely not covered" behaved identically.
final martZoneProvider = FutureProvider<ZoneModel?>((ref) async {
  final address = ref.watch(selectedAddressProvider);
  double? lat = address?.latitude;
  double? lng = address?.longitude;

  // No saved address: use the device's own position, but ask MART's zone
  // lookup with it. This used to return Food's zone (zoneViewModelProvider)
  // outright -- Food and Mart keep separate zones under different ids, so every
  // Mart request then carried a Food zone id, matched no Mart store, and the
  // Mart section showed no products for most shoppers.
  if (lat == null || lng == null) {
    final position =
        await ref.watch(userLocationProvider.future) ?? UserLocation.lastKnown;
    lat = position?.latitude;
    lng = position?.longitude;
  }

  // Still no coordinates (location off or denied): Food's detector is the only
  // zone we can get. The backend swaps a Food zone id for the Mart zone of the
  // same name, so this still scopes the catalogue correctly.
  if (lat == null || lng == null) {
    return ref.watch(zoneViewModelProvider.future);
  }

  try {
    final json = await ref
        .watch(apiClientProvider)
        .get(ApiPaths.zoneDetect, query: {'lat': lat, 'lng': lng});
    if (json is! Map<String, dynamic>) return null;
    return ZoneModel.fromApi(json);
  } catch (_) {
    // A failed lookup must not empty the catalogue.
    return null;
  }
});

/// Synchronous view of [martZoneProvider] for the repositories, which build a
/// query string rather than awaiting. Only a genuinely serviceable zone is
/// sent — an out-of-service or not-yet-known result must not scope queries to
/// a zone id, the same way Food's own [catalogZoneIdProvider] only ever holds
/// an in-service id.
final martZoneIdProvider = Provider<String?>((ref) {
  final zone = ref.watch(martZoneProvider).value;
  return (zone != null && zone.isInService) ? zone.zoneId : null;
});

/// True once the zone lookup has definitively resolved to out-of-coverage —
/// the same signal Food's home screen uses to show its own coming-soon state.
/// Still-loading, not-yet-detected, and failed lookups all read as false
/// (unknown, not unserviceable) so the catalogue is never hidden before a
/// real answer comes back.
final martZoneUnserviceableProvider = Provider<bool>((ref) {
  final zone = ref.watch(martZoneProvider).value;
  return zone != null && !zone.isInService;
});
