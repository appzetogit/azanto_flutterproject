import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/shared/celebration/coupon_celebration.dart';

/// The celebration must quote what the server actually returned — a popup that
/// invents a code or a saving is worse than no popup at all.
void main() {
  Future<void> open(
    WidgetTester tester, {
    required String code,
    required double savings,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    showCouponCelebration(context, code: code, savings: savings),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('quotes the real code and saving', (tester) async {
    await open(tester, code: 'save50', savings: 137.0);

    expect(find.text('You saved ₹137'), findsOneWidget);
    expect(find.text('SAVE50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the paise when the saving is not whole rupees',
      (tester) async {
    // Whole amounts print bare (₹137 above); anything else keeps both decimals
    // rather than rounding, so the figure matches the bill the customer sees.
    await open(tester, code: 'FLAT40', savings: 40.6);
    expect(find.text('You saved ₹40.60'), findsOneWidget);
  });

  testWidgets('the confetti never eats a tap meant for the card',
      (tester) async {
    await open(tester, code: 'X', savings: 10);
    // The burst is painted inside an IgnorePointer, so Continue stays reachable
    // while it is still running.
    expect(find.byType(IgnorePointer), findsWidgets);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('You saved ₹10'), findsNothing);
  });

  testWidgets('the burst settles on its own', (tester) async {
    await open(tester, code: 'X', savings: 10);
    // Runs to completion without leaving a ticker behind; pumpAndSettle would
    // time out on an endlessly repeating animation.
    await tester.pumpAndSettle(const Duration(seconds: 4));
    expect(find.text('You saved ₹10'), findsOneWidget);
  });
}
