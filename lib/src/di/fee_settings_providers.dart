import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/api_config.dart';
import '../presentation/home/viewmodels/zone_viewmodel.dart';
import '../shared/widgets/tip_your_driver_card.dart' show kDefaultTipPresets;
import 'network_providers.dart';

/// The Food vertical's raw fee settings, fetched once and shared.
///
/// Both the free-delivery threshold and the tip presets live in this one
/// document, so they read it together rather than each making its own call.
/// Zone-scoped: re-fetches whenever [currentZoneIdProvider] changes.
final foodFeeSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final zoneId = ref.watch(currentZoneIdProvider);
  try {
    final data = await ref.watch(apiClientProvider).get<Map<String, dynamic>>(
          ApiPaths.feeSettings,
          query: {'zoneId': zoneId},
        );
    final settings = data['feeSettings'];
    return settings is Map ? settings.cast<String, dynamic>() : const {};
  } catch (_) {
    // A failed lookup must not block the cart; callers fall back to defaults.
    return const {};
  }
});

/// Tip amounts offered on the cart's "Tip your delivery partner" card.
///
/// Set in Admin → fee settings (`tipPresets`). These used to be a hardcoded
/// list in the cart widget, so changing what a store offers meant shipping a
/// new build. The compiled-in list survives only as the fallback for a store
/// that has configured nothing — an empty tip card would be worse than a
/// sensible default.
final foodTipPresetsProvider = FutureProvider<List<double>>((ref) async {
  final settings = await ref.watch(foodFeeSettingsProvider.future);
  return parseTipPresets(settings['tipPresets']);
});

/// Shared by both verticals so Food and Mart cannot disagree on what a valid
/// preset list looks like.
List<double> parseTipPresets(Object? raw) {
  if (raw is! List) return kDefaultTipPresets;
  final parsed = <double>[];
  for (final entry in raw) {
    final value = entry is num ? entry.toDouble() : double.tryParse('$entry');
    // Zero is already offered by the card's own "No Tip" chip.
    if (value == null || value <= 0 || parsed.contains(value)) continue;
    parsed.add(value);
  }
  return parsed.isEmpty ? kDefaultTipPresets : parsed;
}

/// The Food vertical's free-delivery threshold, from the admin panel.
///
/// Zero means the shop runs no free-delivery offer, and the cart hides the
/// progress section rather than promising a target nobody configured. The
/// threshold used to be absent from the backend entirely, so anything showing
/// it had to invent a number.
///
/// Deliberately separate from the Mart provider: the two verticals have their
/// own fee settings, and reading Mart's here would show grocery's threshold on
/// a restaurant order.
final foodFreeDeliveryThresholdProvider = FutureProvider<double>((ref) async {
  final settings = await ref.watch(foodFeeSettingsProvider.future);
  final raw = settings['freeDeliveryThreshold'];
  if (raw is num) return raw.toDouble();
  return double.tryParse('${raw ?? ''}') ?? 0;
});
