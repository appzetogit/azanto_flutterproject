import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/quick/domain/model/product.dart';
import 'package:azanto/src/quick/ui/screens/home/widgets/lowest_prices_ever_row.dart';

/// The Lowest Prices rail sat still until it was dragged. It now drifts on its
/// own — at a constant velocity rather than card-to-card, because animating
/// between cards gives an accelerate/settle pulse however long the duration.
Product _p(String id, double price) =>
    Product(id: id, name: 'Item $id', price: price, sellerId: 's1');

Future<void> _pump(WidgetTester tester, List<Product> products) =>
    tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LowestPricesEverRow(
              products: products,
              onProductTap: (_) {},
            ),
          ),
        ),
      ),
    );

ScrollableState _rail(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first);

void main() {
  // A phone-sized surface: the default 800x600 test window is not a shape this
  // rail is ever laid out at, and reports overflows that do not happen on device.
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2340);
    view.devicePixelRatio = 3.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('the rail drifts without being touched', (tester) async {
    await _pump(tester, [_p('a', 10), _p('b', 20), _p('c', 30)]);
    await tester.pump();

    final start = _rail(tester).position.pixels;
    // Pumped as real frames. A single one-second frame is deliberately ignored
    // by the rail: a gap that large means the app was backgrounded, and
    // honouring it would resume with exactly the lurch this avoids.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final afterOneSecond = _rail(tester).position.pixels;

    expect(afterOneSecond, greaterThan(start));
    // Slow: a couple of dozen pixels a second, not a lurch across the row.
    expect(afterOneSecond - start, lessThan(60));
  });

  testWidgets('it moves gradually, not in jumps', (tester) async {
    await _pump(tester, [_p('a', 10), _p('b', 20), _p('c', 30)]);
    await tester.pump();

    final samples = <double>[];
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      samples.add(_rail(tester).position.pixels);
    }

    // Every step forward, and no step wildly larger than its neighbours —
    // which is what a snapping carousel would produce.
    for (var i = 1; i < samples.length; i++) {
      final step = samples[i] - samples[i - 1];
      expect(step, greaterThan(0));
      expect(step, lessThan(20));
    }
  });

  testWidgets('a single product does not scroll', (tester) async {
    await _pump(tester, [_p('a', 10)]);
    await tester.pump();

    final start = _rail(tester).position.pixels;
    await tester.pump(const Duration(seconds: 2));
    expect(_rail(tester).position.pixels, start);
  });
}
