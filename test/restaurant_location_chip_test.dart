import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/data/models/restaurant_model.dart';
import 'package:azanto/src/presentation/home/widgets/restaurant_card.dart';
import 'package:azanto/src/presentation/restaurant/viewmodels/restaurant_detail_viewmodel.dart';

/// A full address crowded the row it shares with delivery time and distance,
/// and truncating it ("Sri balaji bajrang besi…") told the customer nothing.
/// Collapsed it is one word; tapping reveals the rest.
RestaurantModel _restaurant({required String area}) => RestaurantModel(
      id: 'r1',
      name: 'Sri balajibajrangmithaibakers',
      imageUrl: '',
      rating: 4,
      deliveryTime: '20 to 30',
      deliveryFee: 0,
      tags: const [],
      area: area,
    );

Future<void> _pump(WidgetTester tester, String area) => tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The card fetches the menu for its "Must Try" line; without this the
          // real repository fires an HTTP call and leaves a timer pending.
          restaurantMenuProvider('r1').overrideWith((ref) async => []),
        ],
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: RestaurantCard(restaurant: _restaurant(area: area)),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('collapsed to the first word, with a hint there is more',
      (tester) async {
    await _pump(tester, 'Sri balaji bajrang besides the temple, Jadcherla');
    await tester.pump();

    expect(find.text('Sri…'), findsOneWidget);
    // The whole address must not be occupying the row.
    expect(
      find.text('Sri balaji bajrang besides the temple, Jadcherla'),
      findsNothing,
    );
  });

  testWidgets('a one-word location gets no misleading ellipsis',
      (tester) async {
    await _pump(tester, 'Palasia');
    await tester.pump();

    expect(find.text('Palasia'), findsOneWidget);
    expect(find.text('Palasia…'), findsNothing);
  });

  testWidgets('tapping reveals the full address in a scroller', (tester) async {
    const full = 'Sri balaji bajrang besides the temple, Jadcherla';
    await _pump(tester, full);
    await tester.pump();

    await tester.tap(find.text('Sri…'));
    await tester.pump();

    expect(find.text(full), findsOneWidget);
    // It is horizontally scrollable, so the tail is reachable by hand too.
    final scroller = tester.widget<SingleChildScrollView>(
      find.ancestor(
        of: find.text(full),
        matching: find.byType(SingleChildScrollView),
      ).first,
    );
    expect(scroller.scrollDirection, Axis.horizontal);
  });
}
