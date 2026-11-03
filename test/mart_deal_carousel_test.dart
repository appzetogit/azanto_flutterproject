import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/quick/domain/model/product.dart';
import 'package:azanto/src/quick/domain/model/sale_campaign.dart';
import 'package:azanto/src/quick/ui/screens/home/widgets/housefull_sale_banner.dart';

/// The deal card rotates through the campaign's OWN products, in the admin's
/// order. It used to show whichever product the flash-sale section happened to
/// rank first, which had nothing to do with the configured promotion.

/// Long enough for the dwell to elapse and the slide to finish.
///
/// `pumpAndSettle` is unusable here: the sale heading animates forever by
/// design, so the tree never reaches a settled frame.
Future<void> _advance(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(milliseconds: 700));
}

SaleCampaign _campaign(List<SaleCampaignProduct> products) => SaleCampaign(
      id: 'c',
      title: 'GROCERY SALE',
      dealLabel: 'CRAZY DEALS',
      products: products,
    );

const _three = [
  SaleCampaignProduct(id: 'p1', name: 'Amul Butter', price: 52, mrp: 60),
  SaleCampaignProduct(id: 'p2', name: 'Tata Salt', price: 24, mrp: 30),
  SaleCampaignProduct(id: 'p3', name: 'Parle-G', price: 90, mrp: 100),
];

Future<void> _pump(WidgetTester tester, SaleCampaign campaign) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HousefullSaleBanner(campaign: campaign),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('deal model', () {
    test('parses the products the campaign endpoint sends', () {
      final campaign = SaleCampaign.fromJson({
        'id': 'c',
        'title': 'GROCERY SALE',
        'products': [
          {'_id': 'p1', 'name': 'Amul Butter', 'image': 'i.jpg', 'price': 52, 'mrp': 60},
          // Prices can arrive as strings; images can come only as a list.
          {'_id': 'p2', 'name': 'Tata Salt', 'images': ['s.jpg'], 'price': '24'},
        ],
      });

      expect(campaign.products.length, 2);
      expect(campaign.products.first.price, 52);
      expect(campaign.products.first.discountPercent, 13);
      expect(campaign.products[1].imageUrl, 's.jpg');
      expect(campaign.products[1].price, 24, reason: 'a string price must parse');
      expect(campaign.products[1].mrp, isNull);
      expect(campaign.products[1].discountPercent, isNull,
          reason: 'no MRP means no saving to claim');
    });

    test('never claims a saving the prices do not support', () {
      const same = SaleCampaignProduct(id: 'p', name: 'X', price: 50, mrp: 50);
      const lower = SaleCampaignProduct(id: 'p', name: 'X', price: 50, mrp: 40);
      expect(same.discountPercent, isNull);
      expect(lower.discountPercent, isNull);
    });
  });

  group('deal card', () {
    testWidgets('opens on the admin\'s first product', (tester) async {
      await _pump(tester, _campaign(_three));

      expect(find.text('Amul Butter'), findsOneWidget);
      expect(find.text('₹52'), findsOneWidget);
      expect(find.text('₹60'), findsOneWidget, reason: 'struck-through MRP');
    });

    testWidgets('rotates to the next product on its own', (tester) async {
      await _pump(tester, _campaign(_three));
      expect(find.text('Amul Butter'), findsOneWidget);

      await _advance(tester);
      expect(find.text('Tata Salt'), findsOneWidget);
      expect(find.text('Amul Butter'), findsNothing,
          reason: 'the previous slide must leave, not stack up');

      await _advance(tester);
      expect(find.text('Parle-G'), findsOneWidget);
    });

    testWidgets('wraps back to the first product', (tester) async {
      await _pump(tester, _campaign(_three));

      for (var i = 0; i < 3; i++) {
        await _advance(tester);
      }
      expect(find.text('Amul Butter'), findsOneWidget);
    });

    testWidgets('a single product does not rotate', (tester) async {
      await _pump(tester, _campaign([_three.first]));

      await _advance(tester);
      expect(find.text('Amul Butter'), findsOneWidget);
    });

    testWidgets('no products means no prices invented', (tester) async {
      await _pump(tester, _campaign(const []));

      // The card still renders its label; it just has nothing to show inside.
      expect(find.text('CRAZY'), findsOneWidget);
      expect(find.textContaining('₹'), findsNothing);
    });

    testWidgets('hides the strike-through when there is no MRP',
        (tester) async {
      await _pump(
        tester,
        _campaign(const [SaleCampaignProduct(id: 'p', name: 'Milk', price: 30)]),
      );
      expect(find.text('₹30'), findsOneWidget);
      expect(find.text('₹0'), findsNothing);
    });
  });

  testWidgets('falls back to several deal products when the campaign curates none',
      (tester) async {
    // The live campaign has zero products configured, so this is the path the
    // card actually takes today. It used to be handed a single product and sat
    // static; it now rotates through the deal section like a carousel should.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HousefullSaleBanner(
              dealProducts: [
                for (var i = 0; i < 3; i++)
                  Product(
                    id: 'p$i',
                    name: 'Deal $i',
                    price: 10.0 + i,
                    sellerId: 's1',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Deal 0'), findsOneWidget);

    // Rotates without being touched.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Deal 1'), findsOneWidget);
  });
}
