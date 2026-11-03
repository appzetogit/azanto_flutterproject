import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/quick/domain/model/seller.dart';
import 'package:azanto/src/quick/domain/service/store_resolver.dart';

Seller outlet(String name, {double? km, bool open = true}) => Seller(
      id: name,
      name: name,
      distanceKm: km,
      acceptingOrders: open,
    );

/// Quick Commerce is one company's outlet network, so the app picks the serving
/// outlet instead of asking the customer to choose a merchant. These are the
/// rules that make that choice defensible.
void main() {
  test('nearest open outlet serves the order', () {
    // Mirrors the live data shape: the backend does NOT return these sorted.
    final outlets = [
      outlet('Grocery Hub', km: 2.56),
      outlet('Quick Basket', km: 1.65),
      outlet('Appzeto Fresh', km: 0),
      outlet('FreshMart', km: 5.09),
    ];
    expect(StoreResolver.serving(outlets)?.name, 'Appzeto Fresh');
  });

  test('a closed outlet never serves, however near', () {
    // The whole point of resolving is fulfilment. A closed outlet 0km away
    // fulfils nothing, so it must lose to an open one further out.
    final outlets = [
      outlet('Appzeto Fresh', km: 0, open: false),
      outlet('Quick Basket', km: 1.65),
    ];
    expect(StoreResolver.serving(outlets)?.name, 'Quick Basket');
  });

  test('no serving outlet when everything is closed', () {
    final outlets = [outlet('A', km: 1, open: false)];
    // null, not a fallback pick — the UI must show "not serviceable" rather
    // than promise delivery from a shut outlet.
    expect(StoreResolver.serving(outlets), isNull);
  });

  test('outlets beyond the radius are not serviceable', () {
    // MaavaMart really is 669km away in the live data.
    final outlets = [outlet('MaavaMart', km: 669.24)];
    expect(StoreResolver.serving(outlets, maxDistanceKm: 25), isNull);
    expect(StoreResolver.serving(outlets), isNotNull, reason: 'no cap = allowed');
  });

  test('unknown distance sorts last, not first', () {
    // A missing distance is not a good distance; treating null as 0 would let
    // an unlocated outlet beat the one actually next door.
    final outlets = [outlet('Unknown'), outlet('Quick Basket', km: 1.65)];
    expect(StoreResolver.serving(outlets)?.name, 'Quick Basket');
  });

  test('nearby list is nearest-first with open outlets ahead of closed', () {
    final ordered = StoreResolver.nearby([
      outlet('Daily Needs', km: 5.26),
      outlet('Shut But Close', km: 0.2, open: false),
      outlet('Quick Basket', km: 1.65),
    ]);
    expect(ordered.map((o) => o.name).toList(),
        ['Quick Basket', 'Daily Needs', 'Shut But Close']);
  });
}
