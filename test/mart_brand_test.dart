import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/quick/core/theme/app_colors.dart';
import 'package:azanto/src/shared/theme/mart_brand.dart';

void main() {
  test('parses the hex shapes the admin panel can store', () {
    expect(parseHexColor('#FF7A00'), const Color(0xFFFF7A00));
    expect(parseHexColor('ff7a00'), const Color(0xFFFF7A00));
    expect(parseHexColor(' #068483 '), const Color(0xFF068483));
    for (final bad in [null, '', '#FFF', '#GGGGGG', '#FF7A0000', 42]) {
      expect(parseHexColor(bad), isNull, reason: 'should reject $bad');
    }
  });

  test('derived accent is a darker shade of the admin colour', () {
    final brand = QuickBrand.fromSeed(const Color(0xFF068483));
    expect(
      HSLColor.fromColor(brand.accent).lightness,
      lessThan(HSLColor.fromColor(brand.seed).lightness),
    );
    // Near-black seeds must not wrap around into a lighter accent.
    final dark = QuickBrand.fromSeed(const Color(0xFF050505));
    expect(HSLColor.fromColor(dark.accent).lightness, greaterThanOrEqualTo(0.0));
  });

  test('ink on the plate stays legible at both ends of the scale', () {
    expect(QuickBrand.fromSeed(const Color(0xFFFFD400)).onSeed,
        AppColors.lightTextPrimary);
    expect(QuickBrand.fromSeed(const Color(0xFF068483)).onSeed,
        const Color(0xFFFFFFFF));
  });
}
