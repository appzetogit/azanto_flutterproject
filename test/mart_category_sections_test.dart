import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/quick/domain/model/category.dart';
import 'package:azanto/src/quick/ui/screens/home/widgets/all_category_sections_feed.dart';

/// The sections were four hardcoded blocks of invented subcategories carrying
/// made-up ids ('veg_fruits', 'paan_corner'), matched to real categories by
/// fuzzy name — so every tile pushed a route the backend had never heard of.
/// Any category matching none of the blocks was given four OTHER top-level
/// categories as its "subcategories".

const _tree = [
  Category(id: 'grocery', name: 'Grocery'),
  Category(id: 'rice', name: 'Rice & Grains', parentId: 'grocery'),
  Category(id: 'atta', name: 'Atta & Flour', parentId: 'grocery'),
  Category(id: 'snacks', name: 'Snacks & Beverages'),
  Category(id: 'chips', name: 'Chips', parentId: 'snacks'),
  // Top-level with no children of its own.
  Category(id: 'lonely', name: 'Stationery'),
];

Future<void> _pump(WidgetTester tester, {void Function(String)? onTap}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AllCategorySectionsFeed(
              categories: _tree,
              onCategoryTap: onTap ?? (_) {},
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('each section shows that parent\'s own children', (tester) async {
    await _pump(tester);

    expect(find.text('Grocery'), findsOneWidget);
    expect(find.text('Rice & Grains'), findsOneWidget);
    expect(find.text('Atta & Flour'), findsOneWidget);

    expect(find.text('Snacks & Beverages'), findsOneWidget);
    expect(find.text('Chips'), findsOneWidget);
  });

  testWidgets('a childless category gets no empty section', (tester) async {
    await _pump(tester);
    expect(find.text('Stationery'), findsNothing,
        reason: 'a heading over an empty grid reads as a failed load');
  });

  testWidgets('children never appear under the wrong parent', (tester) async {
    await _pump(tester);

    // 'Chips' must sit under Snacks, not be borrowed into the Grocery grid the
    // way the fuzzy name matching used to borrow unrelated categories.
    final grocerySection = tester
        .getTopLeft(find.text('Grocery'))
        .dy;
    final snacksSection = tester
        .getTopLeft(find.text('Snacks & Beverages'))
        .dy;
    final chips = tester.getTopLeft(find.text('Chips')).dy;
    expect(chips, greaterThan(snacksSection));
    expect(snacksSection, greaterThan(grocerySection));
  });

  testWidgets('a tile opens the real category id it shows', (tester) async {
    String? tapped;
    await _pump(tester, onTap: (id) => tapped = id);

    await tester.tap(find.text('Rice & Grains'));
    expect(tapped, 'rice',
        reason: 'tiles used to carry invented ids and route nowhere');
  });

  testWidgets('an empty catalogue renders nothing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AllCategorySectionsFeed(
            categories: const [],
            onCategoryTap: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(GridView), findsNothing);
  });
}
