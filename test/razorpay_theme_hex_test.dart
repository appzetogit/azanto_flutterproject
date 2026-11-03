import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/presentation/branding/app_colors.dart';

/// The Razorpay sheet takes its accent as a `#RRGGBB` string, and a malformed
/// one is ignored silently — the sheet just comes back in Razorpay's own blue
/// with nothing logged. So the conversion is worth pinning down.
void main() {
  final original = AppColors.primary;
  tearDown(() => AppColors.primary = original);

  test('the brand violet converts to the hex the sheet expects', () {
    AppColors.primary = const Color(0xFF8B5CF6);
    expect(AppColors.primaryHex, '#8B5CF6');
  });

  test('the alpha channel is dropped, not printed', () {
    // toARGB32 leads with FF; passing #FF8B5CF6 would be rejected.
    expect(AppColors.primaryHex.length, 7);
  });

  test('dark channels keep their leading zeros', () {
    // '#0A0B0C' must not collapse to '#A0B0C', which is a different colour.
    AppColors.primary = const Color(0xFF0A0B0C);
    expect(AppColors.primaryHex, '#0A0B0C');
    AppColors.primary = const Color(0xFF000000);
    expect(AppColors.primaryHex, '#000000');
  });

  test('it follows a theme colour picked in-app', () {
    AppColors.primary = const Color(0xFF16A34A);
    expect(AppColors.primaryHex, '#16A34A');
  });
}
