import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/zone_model.dart';
import '../../../di/catalog_providers.dart';
import 'user_location_provider.dart';

/// Detects the serviceable zone for the user's location.
///
/// The zone is kept for delivery fees, COD and zone-targeted banners. It no
/// longer scopes restaurant listings or search — those go by distance range
/// from the delivery point. When location
/// is unavailable or the point is out of coverage, we fall back to unscoped
/// (national) listings rather than showing an empty app.
final zoneViewModelProvider =
    AsyncNotifierProvider<ZoneViewModel, ZoneModel>(ZoneViewModel.new);

class ZoneViewModel extends AsyncNotifier<ZoneModel> {
  @override
  FutureOr<ZoneModel> build() => _detect();

  Future<ZoneModel> _detect() async {
    // The delivery address decides the zone, not the phone: a customer in
    // Bhiwandi ordering to Indore is served by Indore's zone, and the zone id
    // is a strict filter on every listing.
    ref.watch(deliveryPointProvider);
    await UserLocation.current();
    final point = UserLocation.discoveryPoint;
    if (point == null) return ZoneModel.unknown;

    final repo = ref.read(catalogRemoteDataSourceProvider);
    try {
      return await repo.detectZone(lat: point.lat, lng: point.lng);
    } catch (_) {
      // Zone detection must never hard-fail the app — unscoped listings are a
      // usable fallback.
      return ZoneModel.unknown;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _detect());
  }
}

/// The zone id to scope catalog calls with, or null when undetected.
final currentZoneIdProvider = Provider<String?>((ref) {
  return ref.watch(zoneViewModelProvider).value?.zoneId;
});

/// Zone id the catalogue (restaurants, dishes, search) is scoped to. Same as
/// [currentZoneIdProvider]; kept separate so listings and checkout can diverge.
final catalogZoneIdProvider = Provider<String?>((ref) {
  return ref.watch(currentZoneIdProvider);
});
