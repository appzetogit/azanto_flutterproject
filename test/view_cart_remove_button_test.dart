import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/presentation/cart/widgets/floating_view_cart_bar.dart';

/// The cart bar offered only "View Cart"; emptying the cart meant opening it
/// first. Remove now sits behind the bar and is uncovered by swiping the bar
/// left, the same shape as a Dismissible's background.
///
/// Remove is deliberately not reachable until then: the bar's whole surface
/// opens the cart, so a destructive action sitting on it permanently is one
/// stray tap from wiping a cart.
Future<void> _pump(
  WidgetTester tester, {
  required VoidCallback onTap,
  VoidCallback? onRemove,
}) =>
    tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                FloatingViewCartBar(
                  onTap: onTap,
                  onRemove: onRemove,
                  itemCount: 2,
                  subtotal: 300,
                  quantity: 2,
                  imageUrls: const [],
                ),
              ],
            ),
          ),
        ),
      ),
    );

/// How far the bar has been slid aside, in pixels (0 = closed).
///
/// Read off the rendered transform rather than the controller: Remove is
/// always in the tree, just covered, so "is it revealed" is a question about
/// position, not about presence.
double _slide(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find
        .ancestor(of: find.text('View Cart'), matching: find.byType(Transform))
        .first,
  );
  return -transform.transform.getTranslation().x;
}

void main() {
  /// Swipes the bar open the way a rider would — a short flick, which the
  /// velocity check in _onDragEnd is there to honour.
  Future<void> reveal(WidgetTester tester) async {
    await tester.fling(find.text('View Cart'), const Offset(-120, 0), 800);
    await tester.pumpAndSettle();
  }

  testWidgets('the bar starts closed, with Remove still covered',
      (tester) async {
    await _pump(tester, onTap: () {}, onRemove: () {});
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('View Cart'), findsOneWidget);
    expect(_slide(tester), 0);
  });

  testWidgets('swiping the bar left uncovers Remove', (tester) async {
    await _pump(tester, onTap: () => fail('must not open the cart'),
        onRemove: () {});
    await tester.pump(const Duration(milliseconds: 600));
    await reveal(tester);

    expect(_slide(tester), greaterThan(0));
    expect(find.text('Remove'), findsOneWidget);

    // Remove is uncovered to the right of the bar it slid out from behind.
    final view = tester.getCenter(find.text('View Cart'));
    final remove = tester.getCenter(find.text('Remove'));
    expect(view.dx, lessThan(remove.dx));
    // Same row, not stacked.
    expect((remove.dy - view.dy).abs(), lessThan(4));
  });

  testWidgets('tapping the revealed Remove clears without opening the cart',
      (tester) async {
    var opened = 0;
    var removed = 0;
    await _pump(tester, onTap: () => opened++, onRemove: () => removed++);
    await tester.pump(const Duration(milliseconds: 600));
    await reveal(tester);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(removed, 1);
    expect(opened, 0, reason: 'the tap must not fall through to View Cart');
  });

  testWidgets('tapping the bar still opens the cart', (tester) async {
    var opened = 0;
    await _pump(tester, onTap: () => opened++, onRemove: () {});
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('View Cart'));
    await tester.pump();

    expect(opened, 1);
  });

  testWidgets('a tap on the slid-aside bar closes it instead of opening',
      (tester) async {
    var opened = 0;
    await _pump(tester, onTap: () => opened++, onRemove: () {});
    await tester.pump(const Duration(milliseconds: 600));
    await reveal(tester);

    await tester.tap(find.text('View Cart'));
    await tester.pumpAndSettle();

    expect(opened, 0, reason: 'the way out of the gesture, not a cart open');
    expect(_slide(tester), 0);
  });

  testWidgets('the bar will not budge when the host supplies no way to clear',
      (tester) async {
    await _pump(tester, onTap: () {});
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Remove'), findsNothing);
    await tester.fling(find.text('View Cart'), const Offset(-120, 0), 800);
    await tester.pumpAndSettle();
    expect(_slide(tester), 0);
  });
}
