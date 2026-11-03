import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/presentation/cart/widgets/floating_view_cart_bar.dart';

/// The bar was positioned from the physical screen edge, so on a device with a
/// gesture bar it sat inside the system inset and came out clipped. It only
/// showed up once the shell auto-hid its own bottom nav on scroll — until then
/// the nav happened to cover the inset.
Future<void> _pump(WidgetTester tester, {required double inset}) =>
    tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(viewPadding: EdgeInsets.only(bottom: inset)),
            child: Scaffold(
              body: Stack(
                children: [
                  FloatingViewCartBar(
                    onTap: () {},
                    bottomOffset: 12,
                    itemCount: 2,
                    subtotal: 147,
                    quantity: 2,
                    imageUrls: const [],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

double _barBottomGap(WidgetTester tester) {
  final screen = tester.getSize(find.byType(MaterialApp)).height;
  return screen - tester.getRect(find.text('View Cart')).bottom;
}

void main() {
  testWidgets('clears a gesture bar', (tester) async {
    await _pump(tester, inset: 48);
    await tester.pump(const Duration(milliseconds: 600));

    // Must sit above the inset, not inside it.
    expect(_barBottomGap(tester), greaterThan(48));
  });

  testWidgets('a taller inset pushes it further up, not off', (tester) async {
    await _pump(tester, inset: 24);
    await tester.pump(const Duration(milliseconds: 600));
    final small = _barBottomGap(tester);

    await _pump(tester, inset: 64);
    await tester.pump(const Duration(milliseconds: 600));
    final large = _barBottomGap(tester);

    expect(large, greaterThan(small));
    expect(large - small, closeTo(40, 1));
  });

  testWidgets('no inset keeps the host offset as-is', (tester) async {
    await _pump(tester, inset: 0);
    await tester.pump(const Duration(milliseconds: 600));

    // Still on screen, still above the edge.
    expect(_barBottomGap(tester), greaterThan(0));
  });
}
