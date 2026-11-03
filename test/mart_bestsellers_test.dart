import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/quick/domain/model/category.dart';
import 'package:azanto/src/quick/domain/model/product.dart';
import 'package:azanto/src/quick/domain/model/sale_campaign.dart';
import 'package:azanto/src/quick/ui/screens/home/home_state.dart';
import 'package:azanto/src/quick/ui/screens/home/widgets/bestsellers_row.dart';

/// The tiles used to be six hardcoded categories with hardcoded stock photos
/// and invented counts ('+172 more'), and a tap fuzzy-matched the fake title
/// against the real list, falling back to `categories.first`. Everything here
/// asserts the tile now says something true about the catalogue.

Product _product(String id, String image) =>
    Product(id: id, name: id, price: 10, sellerId: 's', imageUrl: image);

HomeSection _section(String categoryId, List<Product> products) => HomeSection(
      id: 'category-$categoryId',
      title: categoryId,
      products: products,
      categoryId: categoryId,
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<Category> categories,
  List<HomeSection> sections = const [],
  List<SaleCampaign> campaigns = const [],
  void Function(String)? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BestsellersRow(
            categories: categories,
            sections: sections,
            campaigns: campaigns,
            onCategoryTap: onTap ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('ranks categories by real stock and caps the grid at six',
      (tester) async {
    await _pump(
      tester,
      categories: [
        for (var i = 1; i <= 8; i++)
          Category(id: 'c$i', name: 'Cat $i', itemCount: i),
        // Children never get their own tile — a tile opens a whole branch.
        const Category(id: 'kid', name: 'Child', parentId: 'c8', itemCount: 99),
        // Nothing to sell, nothing to rank.
        const Category(id: 'empty', name: 'Empty', itemCount: 0),
      ],
    );

    expect(find.text('Cat 8'), findsOneWidget);
    expect(find.text('Cat 3'), findsOneWidget);
    expect(find.text('Cat 2'), findsNothing, reason: 'ranked out of the top six');
    expect(find.text('Child'), findsNothing);
    expect(find.text('Empty'), findsNothing);
  });

  testWidgets('the pill counts what the collage does not show', (tester) async {
    await _pump(
      tester,
      categories: const [Category(id: 'c1', name: 'Snacks', itemCount: 30)],
      sections: [
        _section('c1', [
          for (var i = 0; i < 6; i++) _product('p$i', 'https://img/$i.jpg'),
        ]),
      ],
    );
    // Four photos on screen, thirty in the category.
    expect(find.text('+26 more'), findsOneWidget);
  });

  testWidgets('no pill when the collage already shows everything',
      (tester) async {
    await _pump(
      tester,
      categories: const [Category(id: 'c1', name: 'Snacks', itemCount: 2)],
      sections: [
        _section('c1', [
          _product('p0', 'https://img/0.jpg'),
          _product('p1', 'https://img/1.jpg'),
        ]),
      ],
    );
    expect(find.textContaining('more'), findsNothing);
  });

  testWidgets('a tile opens its own category, never a fallback', (tester) async {
    String? tapped;
    await _pump(
      tester,
      categories: const [
        Category(id: 'first', name: 'Alpha', itemCount: 5),
        Category(id: 'second', name: 'Beta', itemCount: 9),
      ],
      onTap: (id) => tapped = id,
    );
    await tester.tap(find.text('Alpha'));
    expect(tapped, 'first');
  });

  testWidgets('an empty catalogue renders nothing rather than empty frames',
      (tester) async {
    await _pump(tester, categories: const []);
    expect(find.text('Bestsellers'), findsNothing);
  });
}
