import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/data/models/address_model.dart';
import 'package:azanto/src/presentation/mode/app_mode.dart';
import 'package:azanto/src/quick/domain/model/address.dart' as quick;
import 'package:azanto/src/shared/address/global_address.dart';
import 'package:azanto/src/shared/orders/global_orders.dart';

/// Guards the global-merge contract: both verticals read the same address row
/// and the same order history, so anything lost in the projection between their
/// two model shapes is a bug the UI would only reveal at checkout.
void main() {
  group('address projection is lossless both ways', () {
    final shared = const AddressModel(
      id: 'a1',
      title: 'Office',
      fullAddress: 'Floor 3, 12 MG Road, Indore, MP, 452001',
      type: 'Office',
      isDefault: true,
      contactPhone: '9876543210',
      street: '12 MG Road',
      additionalDetails: 'Floor 3',
      city: 'Indore',
      state: 'MP',
      zipCode: '452001',
      latitude: 22.72,
      longitude: 75.88,
    );

    test('shared -> quick keeps every field checkout needs', () {
      final q = shared.toQuick();

      expect(q.id, 'a1');
      expect(q.label, quick.AddressLabel.office);
      expect(q.street, '12 MG Road');
      // Regression guard: additionalDetails was absent from AddressModel before
      // the merge, so the flat/floor line silently vanished on a round trip.
      expect(q.additionalDetails, 'Floor 3');
      expect(q.city, 'Indore');
      expect(q.state, 'MP');
      expect(q.zipCode, '452001');
      expect(q.phone, '9876543210');
      expect(q.isDefault, isTrue);
      // Coordinates decide serviceability; losing them silently blocks orders.
      expect(q.latitude, 22.72);
      expect(q.longitude, 75.88);
      expect(q.hasCoordinates, isTrue);
    });

    test('round trip through the quick model changes nothing', () {
      final back = shared.toQuick().toShared();

      expect(back.id, shared.id);
      expect(back.type, shared.type);
      expect(back.street, shared.street);
      expect(back.additionalDetails, shared.additionalDetails);
      expect(back.city, shared.city);
      expect(back.state, shared.state);
      expect(back.zipCode, shared.zipCode);
      expect(back.contactPhone, shared.contactPhone);
      expect(back.isDefault, shared.isDefault);
      expect(back.latitude, shared.latitude);
      expect(back.longitude, shared.longitude);
    });

    test('an address the user never pinned survives without coordinates', () {
      const unpinned = AddressModel(
        id: 'a2',
        title: 'Home',
        fullAddress: '5 Park Lane',
        type: 'Home',
        street: '5 Park Lane',
      );

      final q = unpinned.toQuick();
      expect(q.hasCoordinates, isFalse);
      expect(q.toShared().latitude, isNull);
      expect(q.toShared().street, '5 Park Lane');
    });

    test('the API payload carries the flat/floor line', () {
      expect(shared.toApiPayload()['additionalDetails'], 'Floor 3');
      expect(shared.toOrderPayload()['additionalDetails'], 'Floor 3');
    });
  });

  group('global order rows route to their own vertical', () {
    OrderSummary summary(AppMode mode) => OrderSummary(
          id: 'o1',
          displayId: 'FOD-1',
          mode: mode,
          storeName: 'Store',
          statusLabel: 'Delivered',
          total: 240,
          itemCount: 2,
          isActive: false,
        );

    test('a food order opens the food details screen', () {
      final o = summary(AppMode.food);
      expect(o.isFood, isTrue);
      expect(o.detailsRoute, '/orders/details/o1');
    });

    test('a quick order opens the quick details screen', () {
      final o = summary(AppMode.quick);
      expect(o.isFood, isFalse);
      // Must stay under /quick — the food route would 404 the id.
      expect(o.detailsRoute, '/quick/order/o1');
    });
  });
}
