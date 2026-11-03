import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/shared/celebration/free_delivery_celebration.dart';
import 'package:azanto/src/shared/widgets/free_delivery_progress.dart';

/// Free delivery is celebrated with the coupon card, and the unlock is a moment
/// the shopper earns once. Two things had to be true for it to land at all:
/// the trigger cannot live in the progress bar (it sits below the fold in a
/// lazily-built list, so on open it does not exist yet), and it cannot rely on
/// seeing a false→true transition (the threshold is crossed while browsing,
/// long before any cart is on screen).
class _Cart extends StatefulWidget {
  const _Cart({required this.spent, this.threshold = 199, this.scope = 'test'});

  final double spent;
  final double threshold;
  final String scope;

  @override
  State<_Cart> createState() => _CartState();
}

class _CartState extends State<_Cart> {
  final GlobalKey _sectionKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      celebrateFreeDeliveryUnlock(
        context,
        scope: widget.scope,
        unlocked: widget.spent >= widget.threshold,
        threshold: widget.threshold,
        sectionKey: _sectionKey,
      );
    });

    return ListView(
      cacheExtent: 2000,
      children: [
        // Below the fold, exactly as both real carts place it.
        const SizedBox(height: 2000),
        FreeDeliveryProgress(
          key: _sectionKey,
          spent: widget.spent,
          threshold: widget.threshold,
          formatAmount: (a) => '₹${a.toStringAsFixed(0)}',
        ),
      ],
    );
  }
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

Finder get _card => find.text('FREE delivery unlocked');

void main() {
  setUp(resetFreeDeliveryCelebrations);

  testWidgets('opening a cart that is over the threshold does not show popup dialog',
      (tester) async {
    await tester.pumpWidget(_app(const _Cart(spent: 220)));
    await tester.pumpAndSettle();
    expect(_card, findsNothing);
  });

  testWidgets('scrolls the page to the bar', (tester) async {
    await tester.pumpWidget(_app(const _Cart(spent: 220)));
    await tester.pumpAndSettle();
    expect(find.text('You unlocked FREE delivery'), findsOneWidget);
  });

  testWidgets('a cart under the threshold celebrates nothing', (tester) async {
    await tester.pumpWidget(_app(const _Cart(spent: 150)));
    await tester.pumpAndSettle();
    expect(_card, findsNothing);
  });

  testWidgets('a shop running no offer celebrates nothing', (tester) async {
    await tester.pumpWidget(_app(const _Cart(spent: 220, threshold: 0)));
    await tester.pumpAndSettle();
    expect(_card, findsNothing);
  });
}
