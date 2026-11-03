import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/home/viewmodels/user_location_provider.dart';
import '../data/repository_impl/api_paths.dart';
import 'repository_providers.dart';
import 'app_providers.dart';
import 'zone_providers.dart';

/// Whether any Mart store serving the shopper's zone can take an order now.
class MartStoreStatus {
  const MartStoreStatus({
    required this.isOpen,
    this.reason = 'open',
    this.opensAt,
    this.hours,
    this.etaMinutes,
    this.nextOpeningTimeText,
  });

  final bool isOpen;

  /// 'open', 'outside-hours', 'offline' or 'no-stores'.
  final String reason;

  /// "9:00 AM" when a store opens again later today, otherwise null.
  final String? opensAt;

  /// Today's delivery hours, e.g. "6:00 AM - 11:00 PM", sent whenever closed.
  final String? hours;

  /// Delivery promise from the nearest open store to this shopper -- packing
  /// plus the ride, the same number checkout quotes. Null without a position.
  final int? etaMinutes;

  /// The line the header shows when closed, written by the backend:
  /// "Please come back at 6:00 am" or "Please come back between 6:00 am -
  /// 11:00 pm".
  final String? nextOpeningTimeText;

  static const open = MartStoreStatus(isOpen: true);
}

/// Asked for the current zone, and again every minute so the banner comes and
/// goes as stores open and close while the home screen stays up. A failed
/// check reads as open: the banner is a courtesy, and checkout still refuses
/// a closed store on its own.
final martStoreStatusProvider = FutureProvider.autoDispose<MartStoreStatus>((ref) async {
  final zoneId = ref.watch(martZoneIdProvider);
  // The saved address first, then the device's own position: the backend needs
  // a point to work out how long delivery takes from the nearest store.
  final address = ref.watch(selectedAddressProvider);
  final lat = address?.latitude ?? UserLocation.lastKnown?.latitude;
  final lng = address?.longitude ?? UserLocation.lastKnown?.longitude;
  final timer = Timer(const Duration(minutes: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);

  try {
    final data = await ref.watch(apiClientProvider).get(
          ApiPaths.storeStatus,
          query: {
            if (zoneId != null && zoneId.isNotEmpty) 'zoneId': zoneId,
            if (lat != null && lng != null) ...{'lat': lat, 'lng': lng},
          },
          requiresAuth: false,
        );
    if (data is! Map) return MartStoreStatus.open;
    // No stores at all is shown by the maintenance screen, not this banner.
    if (data['hasStores'] == false) return MartStoreStatus.open;
    return MartStoreStatus(
      isOpen: data['isOpen'] != false,
      reason: data['reason']?.toString() ?? 'open',
      opensAt: data['opensAt']?.toString(),
      hours: data['hours']?.toString(),
      etaMinutes: (data['etaMinutes'] as num?)?.toInt(),
      nextOpeningTimeText: data['nextOpeningTimeText']?.toString(),
    );
  } catch (_) {
    return MartStoreStatus.open;
  }
});
