import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/quick/core/local_storage/local_storage.dart';
import 'package:azanto/src/quick/di/repository_providers.dart'
    show localStorageProvider;
import 'package:azanto/src/quick/domain/model/category.dart';
import 'package:azanto/src/quick/ui/common/widgets/inputs/search_bar_widget.dart';
import 'package:azanto/src/quick/ui/screens/category/categories/categories_provider.dart';
import 'package:azanto/src/quick/ui/screens/category/categories/categories_screen.dart';
import 'package:azanto/src/quick/ui/screens/home/widgets/delivery_header.dart';

/// The Categories tab embedded the HOME screen's header — delivery ETA, address
/// and category strip — then put a second search bar under it. Two search
/// fields on one screen, and an empty category strip because the embedded
/// header was built with no categories.

/// The cart bar at the foot of this screen reaches for persisted state.
class _MemoryStorage implements LocalStorage {
  final _values = <String, Object>{};
  @override
  String? getString(String key) => _values[key] as String?;
  @override
  Future<void> setString(String key, String value) async => _values[key] = value;
  @override
  bool? getBool(String key) => _values[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;
  @override
  List<String> getStringList(String key) =>
      (_values[key] as List<String>?) ?? const [];
  @override
  Future<void> setStringList(String key, List<String> value) async =>
      _values[key] = value;
  @override
  Future<void> remove(String key) async => _values.remove(key);
}

const _tree = [
  Category(id: 'grocery', name: 'Grocery'),
  Category(id: 'rice', name: 'Rice & Pulses', parentId: 'grocery'),
  Category(id: 'atta', name: 'Atta & Flour', parentId: 'grocery'),
  Category(id: 'snacks', name: 'Snacks & Beverages'),
  Category(id: 'chips', name: 'Chips', parentId: 'snacks'),
  Category(id: 'lonely', name: 'Stationery'),
];

Future<void> _pump(WidgetTester tester, List<Category> tree) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        categoryTreeProvider.overrideWith((ref) async => tree),
        localStorageProvider.overrideWithValue(_MemoryStorage()),
      ],
      child: const MaterialApp(home: CategoriesScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('exactly one search bar', (tester) async {
    await _pump(tester, _tree);
    expect(find.byType(SearchBarWidget), findsOneWidget);
  });

  testWidgets('does not borrow the home screen header', (tester) async {
    await _pump(tester, _tree);
    expect(find.byType(DeliveryHeader), findsNothing);
    // Its own header instead.
    expect(find.text('All Categories'), findsOneWidget);
  });

  testWidgets('sections are real parents holding their real children',
      (tester) async {
    await _pump(tester, _tree);

    expect(find.text('Grocery'), findsOneWidget);
    expect(find.text('Rice & Pulses'), findsOneWidget);
    expect(find.text('Atta & Flour'), findsOneWidget);
    expect(find.text('Snacks & Beverages'), findsOneWidget);
    expect(find.text('Chips'), findsOneWidget);

    // The old keyword buckets invented these headings and swept anything
    // unmatched into the last one.
    expect(find.text('Grocery & Kitchen'), findsNothing);
    expect(find.text('Household Essentials'), findsNothing);
  });

  testWidgets('a childless category gets no empty section', (tester) async {
    await _pump(tester, _tree);
    expect(find.text('Stationery'), findsNothing);
  });

  testWidgets('a catalogue with no tree still lists what it has',
      (tester) async {
    await _pump(tester, const [
      Category(id: 'a', name: 'Alpha'),
      Category(id: 'b', name: 'Beta'),
    ]);

    expect(find.text('All categories'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('an empty catalogue shows the empty state', (tester) async {
    await _pump(tester, const []);
    expect(find.text('No categories yet'), findsOneWidget);
  });
}
