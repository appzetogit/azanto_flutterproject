import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../address/viewmodels/address_viewmodel.dart';
import '../../../di/location_providers.dart';

/// The device's current position, or null when location is off or denied.
///
/// Shared so the restaurant listing can send `lat`/`lng` alongside zone
/// detection. Without those params the backend cannot compute `distanceInKm`,
/// which is why every restaurant card showed no real distance.
///
/// Cached for [_ttl]: a fresh GPS fix per list request would be slow and drain
/// battery, and a customer does not move far enough between requests for it to
/// matter.
final userLocationProvider = FutureProvider<Position?>((ref) async {
  return UserLocation.current(forceRefresh: true);
});

/// Plain lat/lng of the *phone*, for callers that only need the numbers.
///
/// Discovery should use [deliveryPointProvider] instead — see the note there.
final userLatLngProvider = Provider<({double lat, double lng})?>((ref) {
  final p = ref.watch(userLocationProvider).asData?.value;
  return p == null ? null : (lat: p.latitude, lng: p.longitude);
});

/// Where to look for restaurants: the delivery address the customer picked,
/// falling back to the phone's own position.
///
/// The listing used to be driven by GPS alone, so ordering to an Indore address
/// from a phone sitting in Bhiwandi still listed Bhiwandi restaurants — the food
/// is delivered to the address, so that is what discovery has to follow.
///
/// Also mirrored onto [UserLocation.selectedAddressPoint] for the synchronous
/// call sites (the repository and the catalog datasource) that cannot read a
/// provider mid-request.
final deliveryPointProvider = Provider<({double lat, double lng})?>((ref) {
  // "Use my current location": browse around the phone, whatever address is
  // saved. Checkout still asks for a real address before ordering.
  if (ref.watch(exploringHereProvider)) {
    UserLocation.selectedAddressPoint = null;
    return ref.watch(userLatLngProvider);
  }
  // Watched for the rebuild, read for the selection rule — `defaultAddress`
  // already encodes which of the saved addresses is the live one.
  ref.watch(addressViewModelProvider);
  final address = ref.read(addressViewModelProvider.notifier).defaultAddress;

  final lat = address?.latitude;
  final lng = address?.longitude;
  final point = (lat != null && lng != null) ? (lat: lat, lng: lng) : null;

  UserLocation.selectedAddressPoint = point;
  return point ?? ref.watch(userLatLngProvider);
});

/// True while the customer browses by the phone's location ("Use my current
/// location") rather than a saved address. Picking an address ends it.
///
/// Remembered across restarts: reopening the app used to drop back to the saved
/// default address, which can be in another city.
class ExploringHere extends Notifier<bool> {
  static const _key = 'exploring_here';

  @override
  bool build() {
    // Prefs load asynchronously; the first frame uses the saved address and
    // switches over as soon as the stored choice is read.
    SharedPreferences.getInstance().then((prefs) {
      if (ref.mounted && prefs.getBool(_key) == true) state = true;
    });
    return false;
  }

  void set(bool value) {
    state = value;
    SharedPreferences.getInstance().then((prefs) => prefs.setBool(_key, value));
  }
}

final exploringHereProvider = NotifierProvider<ExploringHere, bool>(
  ExploringHere.new,
);

/// The street address of the phone's position while exploring, for the Home
/// header (it used to say only "Current location"). Null until resolved.
final exploringAddressProvider = FutureProvider<String?>((ref) async {
  if (!ref.watch(exploringHereProvider)) return null;
  final point = ref.watch(userLatLngProvider);
  if (point == null) return null;
  final r = await ref
      .read(locationServiceProvider)
      .reverseGeocode(point.lat, point.lng);
  final text = r.fullAddress.trim();
  // A failed lookup returns "Lat: …, Lng: …", which is not worth showing.
  return text.isEmpty || text.startsWith('Lat:') ? null : text;
});

class UserLocation {
  const UserLocation._();

  static const _ttl = Duration(minutes: 5);

  static Position? _cached;
  static DateTime? _cachedAt;

  /// The picked delivery address's coordinates, mirrored here by
  /// [deliveryPointProvider] so synchronous callers can see it too. Null when
  /// no saved address has coordinates.
  static ({double lat, double lng})? selectedAddressPoint;

  /// The point every catalog request should be made against: the delivery
  /// address first, the phone second.
  static ({double lat, double lng})? get discoveryPoint {
    final picked = selectedAddressPoint;
    if (picked != null) return picked;
    final p = lastKnown;
    return p == null ? null : (lat: p.latitude, lng: p.longitude);
  }

  /// Last known position without waiting on the GPS stack. Used by synchronous
  /// call sites (the repository, search) that cannot await a fix mid-request.
  ///
  /// Deliberately ignores [_ttl]. Both callers use this only to send lat/lng so
  /// the backend can return `distanceInKm`, and returning null past the TTL made
  /// them silently omit the coordinates — distances showed on a fresh launch and
  /// then vanished five minutes later. A slightly stale fix rounds to the same
  /// kilometre; no fix at all shows an em dash. [current] still refreshes on the
  /// TTL, so the staleness is bounded in practice.
  static Position? get lastKnown => _cached;

  /// TTL-aware view of the cache, used only to decide whether to hit the GPS
  /// stack again. [lastKnown] must not use this or it would go back to
  /// returning null and dropping the coordinates.
  static Position? get _fresh {
    final at = _cachedAt;
    if (_cached == null || at == null) return null;
    return DateTime.now().difference(at) > _ttl ? null : _cached;
  }

  static Future<Position?> current({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final fresh = _fresh;
      if (fresh != null) return fresh;
    } else {
      _cached = null;
      _cachedAt = null;
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // A fresh GPS fix can take several seconds, and the home feed waits on
      // this. The phone's last known position is instant and good enough to
      // pick the zone and sort by distance; a fresh fix replaces it behind it.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _cached = last;
        _cachedAt = DateTime.now();
        unawaited(_refresh());
        return last;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _cached = position;
      _cachedAt = DateTime.now();
      return position;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _refresh() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _cached = position;
      _cachedAt = DateTime.now();
    } catch (_) {}
  }
}
