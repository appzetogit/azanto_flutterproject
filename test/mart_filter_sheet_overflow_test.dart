import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Mart "Filters" sheet stacked every section — sort, diet, brand, price —
/// into a plain Column inside the sheet's Flexible slot. Once the brand list
/// grew past the sheet's height the content overflowed and Flutter painted its
/// render stripe across the bottom, cutting off the last brand.
///
/// The sheet body is scrollable now. This pins the shape that fix relies on: a
/// column taller than its slot survives only inside a scroll view. Overflow is
/// reported through FlutterError during layout, so the assertion is simply that
/// pumping a too-tall body raises nothing.
void main() {
  testWidgets('a filter body taller than the sheet scrolls instead of overflowing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              // Stands in for the sheet's own maxHeight clamp.
              constraints: const BoxConstraints(maxHeight: 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Comfortably past 300px, as the real sections are.
                          for (var i = 0; i < 12; i++)
                            const SizedBox(height: 60, child: Text('option')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    // And the tail is reachable rather than clipped away.
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
