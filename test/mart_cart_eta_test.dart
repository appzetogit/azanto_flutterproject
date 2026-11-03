import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/quick/data/dto/pricing_dto.dart';

/// The cart's seller row advertised "0 mins".
///
/// `deliveryPromiseMinutes` is only an estimate the server can make once it has
/// a distance to work from; before then it answers 0 rather than omitting the
/// field. The badge rendered on `!= null`, so 0 slipped through and promised an
/// instant delivery.
void main() {
  test('an absent promise parses as unknown', () {
    expect(PricingDto.fromJson(const {}).deliveryPromiseMinutes, isNull);
  });

  test('a zero promise is what the server sends when it cannot estimate', () {
    // Pinning the shape the UI has to defend against: 0, not null.
    expect(
      PricingDto.fromJson(const {'deliveryPromiseMinutes': 0})
          .deliveryPromiseMinutes,
      0,
    );
  });

  test('a real promise survives', () {
    expect(
      PricingDto.fromJson(const {'deliveryPromiseMinutes': 12})
          .deliveryPromiseMinutes,
      12,
    );
  });

  test('only a positive promise may be shown', () {
    // The rule the badge now applies. Zero and null both mean "no estimate".
    bool shows(int? m) => (m ?? 0) > 0;
    expect(shows(null), isFalse);
    expect(shows(0), isFalse);
    expect(shows(12), isTrue);
  });
}
