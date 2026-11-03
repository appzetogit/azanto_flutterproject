import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/data/models/zone_model.dart';
import 'package:azanto/src/presentation/home/viewmodels/zone_viewmodel.dart';

/// Food listings are scoped by the detected zone, same as Mart's
/// `martZoneIdProvider`. Restaurants without a `zoneId` assigned aren't
/// hidden by this — the backend falls back to the unscoped catalogue when a
/// zone-scoped query returns nothing (see `listApprovedRestaurants` /
/// `listPublicFoods`), so this provider only needs to mirror detection.
class _FixedZoneViewModel extends ZoneViewModel {
  _FixedZoneViewModel(this._zone);
  final ZoneModel _zone;

  @override
  FutureOr<ZoneModel> build() => _zone;
}

void main() {
  test('catalogZoneIdProvider mirrors a detected zone', () async {
    final container = ProviderContainer(
      overrides: [
        zoneViewModelProvider.overrideWith(
          () => _FixedZoneViewModel(
            const ZoneModel(status: 'IN_SERVICE', zoneId: 'zone-indore'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(zoneViewModelProvider.future);

    expect(container.read(catalogZoneIdProvider), 'zone-indore');
    expect(container.read(currentZoneIdProvider), 'zone-indore');
  });

  test('catalogZoneIdProvider is null when no zone is detected', () async {
    final container = ProviderContainer(
      overrides: [
        zoneViewModelProvider.overrideWith(
          () => _FixedZoneViewModel(ZoneModel.unknown),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(zoneViewModelProvider.future);

    expect(container.read(catalogZoneIdProvider), isNull);
  });
}
