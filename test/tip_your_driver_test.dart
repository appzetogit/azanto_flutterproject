import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/di/fee_settings_providers.dart';
import 'package:azanto/src/shared/widgets/tip_your_driver_card.dart';

/// The tip card offered a hardcoded 10/20/30/50 and the chosen amount reached
/// nothing — the backend had no tip field at all, so the money never left the
/// screen. Amounts now come from the admin panel and the selection is reported
/// upward for the host cart to price.
Future<void> _pump(
  WidgetTester tester, {
  required List<double> presets,
  double selected = 0,
  ValueChanged<double>? onSelect,
}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TipYourDriverCard(
              selected: selected,
              presets: presets,
              onSelect: onSelect ?? (_) {},
            ),
          ),
        ),
      ),
    );

void main() {
  group('preset parsing', () {
    test('reads the admin list, dropping junk and duplicates', () {
      expect(parseTipPresets([15, '25', 15, 0, -5, 'x', 40]), [15, 25, 40]);
    });

    test('an unconfigured store falls back rather than showing nothing', () {
      // The card with no chips would read as broken, so the compiled-in list
      // survives strictly as a fallback.
      expect(parseTipPresets(null), kDefaultTipPresets);
      expect(parseTipPresets(const []), kDefaultTipPresets);
      expect(parseTipPresets('nonsense'), kDefaultTipPresets);
    });
  });

  testWidgets('renders the amounts it is given, not a compiled-in list',
      (tester) async {
    await _pump(tester, presets: const [15, 25, 40]);

    expect(find.text('₹15'), findsOneWidget);
    expect(find.text('₹25'), findsOneWidget);
    expect(find.text('₹40'), findsOneWidget);
    // The old hardcoded values must not appear when the admin set others.
    expect(find.text('₹10'), findsNothing);
    expect(find.text('₹50'), findsNothing);
    expect(find.text('No Tip'), findsOneWidget);
  });

  testWidgets('tapping a chip reports that amount to the host', (tester) async {
    final tapped = <double>[];
    await _pump(tester, presets: const [15, 25], onSelect: tapped.add);

    await tester.tap(find.text('₹25'));
    await tester.pump();
    expect(tapped, [25]);

    await tester.tap(find.text('No Tip'));
    await tester.pump();
    expect(tapped, [25, 0]);
  });

  testWidgets('an empty preset list still renders a usable card',
      (tester) async {
    await _pump(tester, presets: const []);

    for (final amount in kDefaultTipPresets) {
      expect(find.text('₹${amount.toStringAsFixed(0)}'), findsOneWidget);
    }
  });
}
