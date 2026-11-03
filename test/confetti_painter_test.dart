import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/shared/celebration/coupon_celebration.dart';

/// The confetti can fail silently: a dialog hands its child *loose*
/// constraints, so the layer that paints the burst can shrink-wrap to the card
/// and end up hidden behind it. That looks exactly like "no animation", so the
/// thing worth asserting is that the painting layer really does span the
/// screen.
void main() {
  test('a burst produces the requested number of chips', () {
    expect(ConfettiParticle.burst(count: 44, seed: 1), hasLength(44));
  });

  testWidgets('the confetti layer spans the whole screen, not just the card',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showCouponCelebration(
                  context,
                  code: 'FREEDEL',
                  savings: 40,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final paint = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is ConfettiPainter,
    );
    expect(paint, findsOneWidget);

    final painted = tester.getSize(paint);
    expect(painted.width, closeTo(screen.width, 1));
    expect(painted.height, closeTo(screen.height, 1));

    // And it must sit behind a card that is much smaller, so the burst is
    // visible around it rather than covered by it.
    final card = tester.getSize(find.byType(Material).last);
    expect(card.height, lessThan(painted.height));
  });

  test('chips are on screen while the burst runs, not flung off instantly', () {
    final chips = ConfettiParticle.burst(count: 44, seed: 3);

    int onScreenAt(double t) => chips.where((c) {
          final p = c.positionAt(t);
          return p.dx >= 0 && p.dx <= 1 && p.dy >= 0 && p.dy <= 1;
        }).length;

    // The first three quarters are cannons from the lower corners, all of them
    // on screen from the off. The last quarter is a cascade seeded just above
    // the top edge so it drifts in — deliberately not on screen at t=0, which
    // is why this is a floor rather than the full count.
    expect(onScreenAt(0.0), greaterThanOrEqualTo(33));
    expect(onScreenAt(0.25), greaterThan(30));
    expect(onScreenAt(0.5), greaterThan(20));
  });

  test('the burst rises before gravity takes over', () {
    final chip = ConfettiParticle.burst(count: 2, seed: 5).first;
    expect(chip.positionAt(0.3).dy, lessThan(chip.origin.dy),
        reason: 'a chip that only ever falls is not a celebration');
  });
}
