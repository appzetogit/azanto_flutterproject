import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/shared/widgets/free_delivery_progress.dart';

/// The threshold is an admin-panel field. It used to be guessed from a zero-fee
/// band in the distance-banded fee table and fell back to a compiled-in 199, so
/// the cart promised free delivery at a number nobody had configured.

Future<void> _pump(
  WidgetTester tester, {
  required double spent,
  required double threshold,
}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FreeDeliveryProgress(
            spent: spent,
            threshold: threshold,
            formatAmount: (a) => '₹${a.toStringAsFixed(0)}',
          ),
        ),
      ),
    );

double _barValue(WidgetTester tester) =>
    tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    ).value ??
    0;

void main() {
  testWidgets('shows the shortfall computed from cart and threshold',
      (tester) async {
    await _pump(tester, spent: 65, threshold: 199);

    expect(find.text('Get FREE delivery'), findsOneWidget);
    expect(find.text('Add products worth ₹134 more'), findsOneWidget);
  });

  testWidgets('the bar tracks how far along the cart is', (tester) async {
    await _pump(tester, spent: 100, threshold: 200);
    await tester.pumpAndSettle();

    expect(_barValue(tester), closeTo(0.5, 0.01));
  });

  testWidgets('reaching the threshold switches to the success message',
      (tester) async {
    await _pump(tester, spent: 199, threshold: 199);
    await tester.pumpAndSettle();

    expect(find.text('You unlocked FREE delivery'), findsOneWidget);
    expect(find.textContaining('Add products worth'), findsNothing);
    expect(_barValue(tester), 1.0);
  });

  testWidgets('overshooting does not push the bar past full', (tester) async {
    await _pump(tester, spent: 500, threshold: 199);
    await tester.pumpAndSettle();

    expect(_barValue(tester), 1.0);
    expect(find.text('You unlocked FREE delivery'), findsOneWidget);
  });

  testWidgets('no configured offer hides the section entirely', (tester) async {
    // Zero is what the app reads when the admin has set no threshold. Showing
    // a bar here would invent a target.
    await _pump(tester, spent: 50, threshold: 0);

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('FREE delivery'), findsNothing);
  });

  testWidgets('an empty cart shows the full amount outstanding',
      (tester) async {
    await _pump(tester, spent: 0, threshold: 250);
    await tester.pumpAndSettle();

    expect(find.text('Add products worth ₹250 more'), findsOneWidget);
    expect(_barValue(tester), 0);
  });
}
