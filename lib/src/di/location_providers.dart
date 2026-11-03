import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../platform/location/location_service.dart';
import '../shared/address/global_address.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// The shopper's current coordinates, or null when location is unavailable.
///
/// Returns the selected delivery address coordinates if available, otherwise
/// falls back to the device's live GPS lookup.
final userCoordsProvider =
    FutureProvider<({double lat, double lng})?>((ref) async {
  final address = ref.watch(globalSelectedAddressProvider);
  if (address?.latitude != null && address?.longitude != null) {
    return (lat: address!.latitude!, lng: address.longitude!);
  }

  try {
    final result =
        await ref.watch(locationServiceProvider).getCurrentLocationAndAddress();
    final lat = result.latitude;
    final lng = result.longitude;
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  } catch (_) {
    return null;
  }
});
