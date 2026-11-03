import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/quick/ui/screens/home/widgets/bouncing_heading.dart';

/// The heading scales up from nothing, its characters hop left to right, it
/// scales back to nothing, and the whole thing repeats.
///
/// Timings come from the widget's own constants rather than being copied here,
/// so retuning a beat cannot silently invalidate these tests.

const _enter = BouncingHeading.enterDuration;
const _exit = BouncingHeading.exitDuration;
const _stagger = BouncingHeading.staggerDuration;

Duration _bounce(String text) => BouncingHeading.bounceFor(text.length);

Future<void> _pump(WidgetTester tester, String text) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BouncingHeading(
              text: text,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      ),
    );

/// Runs the arrival to completion so the bounce beat is under way.
Future<void> _settleEntrance(WidgetTester tester) =>
    tester.pump(_enter + const Duration(milliseconds: 1));

double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find
          .descendant(
            of: find.byType(BouncingHeading),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

/// The scale the heading is currently painted at, measured rather than read
/// off the Transform.
///
/// `Matrix4.getMaxScaleOnAxis()` is no use here: `Transform.scale(scale: 0)`
/// builds `diagonal3Values(0, 0, 1)`, whose largest axis is the untouched Z
/// one, so it reports 1 for a heading scaled away to nothing. Painted width
/// over layout width is the thing actually being asserted anyway.
double _scale(WidgetTester tester) {
  final glyph = find.text('A');
  return tester.getRect(glyph).width / tester.getSize(glyph).width;
}

/// Vertical position of one character. Smaller means higher on screen.
double _y(WidgetTester tester, String glyph) =>
    tester.getTopLeft(find.text(glyph)).dy;

double _x(WidgetTester tester, String glyph) =>
    tester.getTopLeft(find.text(glyph)).dx;

void main() {
  group('beat 1 — scales up from nothing', () {
    testWidgets('starts at nothing: no size, nothing visible', (tester) async {
      await _pump(tester, 'ABCD');
      expect(_scale(tester), 0);
      expect(_opacity(tester), 0);
    });

    testWidgets('grows to full size and full opacity', (tester) async {
      await _pump(tester, 'ABCD');
      final layout = tester.getSize(find.text('A'));

      await tester.pump(const Duration(milliseconds: 120));
      expect(_scale(tester), greaterThan(0));
      expect(_opacity(tester), greaterThan(0));

      await _settleEntrance(tester);
      expect(_scale(tester), closeTo(1, 0.001));
      expect(_opacity(tester), 1);

      // The scale is paint-time, so the heading reserves its final footprint
      // from the very first frame — nothing around it reflows as it arrives.
      expect(tester.getSize(find.text('A')), layout);
    });

    testWidgets('no character hops while the heading is still arriving',
        (tester) async {
      await _pump(tester, 'ABCD');

      // Absolute positions DO move during the arrival — the scale is what moves
      // them. What proves the bounce has not started is that the glyphs stay
      // level with EACH OTHER: a hop lifts one relative to its neighbours,
      // a scale moves all four together.
      for (var i = 0; i < 4; i++) {
        await tester.pump(_enter ~/ 4);
        final rows = {for (final g in 'ABCD'.split('')) _y(tester, g)};
        expect(rows.length, 1,
            reason: 'a character hopped before the heading had landed');
      }
    });
  });

  group('beat 2 — the bounce', () {
    testWidgets('the lift travels left to right, one character behind the next',
        (tester) async {
      await _pump(tester, 'ABCD');
      await _settleEntrance(tester);

      // Glyphs are compared to each other at one instant rather than to a
      // stored baseline: by the first frame of the bounce the leftmost glyph is
      // already rising, so no frame gives a clean "resting" reading.
      await tester.pump(const Duration(milliseconds: 30));
      expect(_y(tester, 'A'), lessThan(_y(tester, 'B')),
          reason: 'A should be rising');
      expect(_y(tester, 'B'), _y(tester, 'C'),
          reason: 'the wave has not reached B or C');
      expect(_y(tester, 'C'), _y(tester, 'D'));

      await tester.pump(_stagger);
      expect(_y(tester, 'B'), lessThan(_y(tester, 'C')));
      expect(_y(tester, 'C'), _y(tester, 'D'),
          reason: 'the wave has not reached C');

      await tester.pump(_stagger);
      expect(_y(tester, 'C'), lessThan(_y(tester, 'D')));
    });

    testWidgets('characters only move vertically — the word never slides',
        (tester) async {
      await _pump(tester, 'ABCD');
      await _settleEntrance(tester);
      final columns = {for (final g in 'ABCD'.split('')) g: _x(tester, g)};

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        for (final g in columns.keys) {
          expect(_x(tester, g), columns[g], reason: '$g drifted sideways');
        }
      }
    });

    testWidgets('the hop stays subtle enough to keep the heading readable',
        (tester) async {
      await _pump(tester, 'ABCD');
      await _settleEntrance(tester);
      final resting = _y(tester, 'A');
      var highest = resting;

      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 35));
        final y = _y(tester, 'A');
        if (y < highest) highest = y;
      }
      expect(resting - highest, greaterThan(0), reason: 'it must actually move');
      expect(resting - highest,
          lessThanOrEqualTo(BouncingHeading.amplitude + 0.5));
    });

    testWidgets('the heading holds full size for the whole bounce',
        (tester) async {
      await _pump(tester, 'ABCD');
      await _settleEntrance(tester);

      final bounce = _bounce('ABCD');
      for (var i = 1; i < 5; i++) {
        await tester.pump(bounce ~/ 6);
        expect(_scale(tester), closeTo(1, 0.001),
            reason: 'it must not shrink mid-bounce');
      }
    });
  });

  group('beat 3 — scales back to nothing', () {
    testWidgets('shrinks away after the bounce and ends at nothing',
        (tester) async {
      await _pump(tester, 'ABCD');
      await _settleEntrance(tester);
      await tester.pump(_bounce('ABCD'));

      // Three quarters through: past the wind-up swell, on its way down.
      await tester.pump(_exit * 3 ~/ 4);
      final shrinking = _scale(tester);
      expect(shrinking, lessThan(1));
      expect(shrinking, greaterThan(0));

      await tester.pump(_exit ~/ 4 + const Duration(milliseconds: 1));
      expect(_scale(tester), 0);
      expect(_opacity(tester), 0);
    });

    testWidgets('layout is untouched even while scaled away', (tester) async {
      await _pump(tester, 'ABCD');
      await _settleEntrance(tester);
      final layout = tester.getSize(find.text('A'));

      await tester.pump(_bounce('ABCD') + _exit);
      expect(tester.getSize(find.text('A')), layout,
          reason: 'the banner must not collapse while the heading is away');
    });
  });

  group('beat 4 — and again', () {
    testWidgets('the whole sequence repeats', (tester) async {
      await _pump(tester, 'ABCD');
      await tester.pump(BouncingHeading.cycleFor(4));

      // Back at the top of the loop: nothing on screen.
      expect(_scale(tester), closeTo(0, 0.001));

      // …and it grows again rather than staying gone.
      await tester.pump(_enter ~/ 2);
      expect(_scale(tester), greaterThan(0));
    });
  });

  group('backend headings', () {
    testWidgets('a screen reader gets the whole heading, not loose letters',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, 'GROCERY SALE');

      expect(find.bySemanticsLabel('GROCERY SALE'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the label holds steady even while scaled away',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, 'GROCERY SALE');
      await tester.pump(_enter + _bounce('GROCERY SALE') + _exit);

      expect(_scale(tester), 0);
      expect(find.bySemanticsLabel('GROCERY SALE'), findsOneWidget,
          reason: 'assistive tech should not lose the heading as it animates');
      handle.dispose();
    });

    testWidgets('spaces survive the split', (tester) async {
      await _pump(tester, 'A B');
      // At full size: while the heading is scaled away every glyph paints at
      // the same point, so widths and gaps are only meaningful once it lands.
      await _settleEntrance(tester);

      expect(find.text(' '), findsOneWidget);
      // A gap wide enough to be the space, not just adjacent letters.
      final gap = _x(tester, 'B') - _x(tester, 'A');
      expect(gap, greaterThan(tester.getSize(find.text('A')).width));
    });

    testWidgets('a new heading restarts the sequence from nothing',
        (tester) async {
      await _pump(tester, 'ABCD');
      await _settleEntrance(tester);
      expect(_scale(tester), closeTo(1, 0.001));

      // Category switches swap the text on the same widget. The new heading
      // keeps an 'A' so the scale stays measurable across the swap.
      await _pump(tester, 'WXYZA');
      expect(_scale(tester), 0, reason: 'the new heading arrives too');

      await _settleEntrance(tester);
      await tester.pump(const Duration(milliseconds: 30));
      expect(_y(tester, 'W'), lessThan(_y(tester, 'Z')),
          reason: 'the wave restarts at the new first character');
    });
  });
}
