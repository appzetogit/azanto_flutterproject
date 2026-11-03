import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/presentation/branding/app_colors.dart';
import 'package:azanto/src/quick/domain/model/sale_campaign.dart';
import 'package:azanto/src/quick/ui/screens/home/widgets/delivery_header.dart';

/// The status bar sits on the header gradient's TOP stop, not on the brand
/// colour. Deciding icon brightness from the brand meant a light-ish brand with
/// a deep ramp end (violet is exactly that) asked for dark icons and put the
/// clock on a dark plate where it vanished.
bool _wantsDarkIcons(SaleCampaign? campaign) =>
    martHeaderGradient(campaign).first.computeLuminance() > 0.45;

SaleCampaign _themed(String hex) =>
    SaleCampaign(id: 'c', title: 'SALE', themeColor: hex);

void main() {
  setUp(() {
    AppColors.primary = const Color(0xFF8B5CF6); // the purple Mart brand
    AppColors.primaryButton = const Color(0xFFA78BFA);
  });

  test('the ramp runs dark to light, top stop first', () {
    final stops = martHeaderGradient(null);
    expect(stops.length, 3);
    double l(Color c) => HSLColor.fromColor(c).lightness;
    expect(l(stops[0]), lessThan(l(stops[1])));
    expect(l(stops[1]), lessThan(l(stops[2])));
  });

  test('a deep brand plate gets light status-bar icons', () {
    // Violet reads "light" (L≈0.66) while its ramp end is dark — the exact case
    // the old brand-based check got backwards.
    expect(HSLColor.fromColor(AppColors.primary).lightness, greaterThan(0.6));
    expect(_wantsDarkIcons(null), isFalse);
  });

  test('a pale category theme gets dark status-bar icons', () {
    expect(_wantsDarkIcons(_themed('#A5DEC0')), isTrue); // Grocery mint
    expect(_wantsDarkIcons(_themed('#FFE49A')), isTrue); // Dairy amber
  });

  test('a campaign with no colour falls back to the brand ramp', () {
    expect(martHeaderGradient(_themed('')), martHeaderGradient(null));
    expect(martHeaderGradient(_themed('not-a-colour')), martHeaderGradient(null));
  });
}
