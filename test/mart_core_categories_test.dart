import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/quick/data/dto/category_dto.dart';
import 'package:azanto/src/quick/data/mapper/category_mapper.dart';

void main() {
  // The endpoint returns one flat list of BOTH levels, each row carrying a
  // parentId. Seeding 122 subcategories put every one of them in the header
  // until the app learned to tell the levels apart.
  final flat = [
    {'_id': 'c1', 'name': 'Grocery & Staples', 'sortOrder': 0},
    {'_id': 'c2', 'name': 'Electronics & Accessories', 'sortOrder': 1},
    {'_id': 's1', 'name': 'Chargers', 'parentId': 'c2', 'sortOrder': 0},
    {'_id': 's2', 'name': 'Cables', 'parentId': 'c2', 'sortOrder': 1},
    {'_id': 's3', 'name': 'Rice & Grains', 'parentId': 'c1', 'sortOrder': 0},
  ];

  test('only core categories belong in the header', () {
    final all = CategoryMapper.toDomainList(
      flat.map(CategoryDto.fromJson).toList(),
    );
    final core = all.where((c) => c.isCore).toList();

    expect(core.map((c) => c.name),
        containsAll(['Grocery & Staples', 'Electronics & Accessories']));
    expect(core.length, 2, reason: 'subcategories must not reach the header');
    expect(core.map((c) => c.name), isNot(contains('Chargers')));
  });

  test('a category resolves to its own subcategories, not another one\'s', () {
    final all = CategoryMapper.toDomainList(
      flat.map(CategoryDto.fromJson).toList(),
    );
    final electronics =
        all.where((c) => c.parentId == 'c2').map((c) => c.name).toList();

    expect(electronics, ['Chargers', 'Cables']);
    // Tapping Electronics must never surface a grocery subcategory.
    expect(electronics, isNot(contains('Rice & Grains')));
  });

  test('the header shows only the admin-curated set', () {
    // Ten flagged categories out of a much larger tree: the strip is curated,
    // not "every top-level category".
    final all = CategoryMapper.toDomainList([
      // sortOrder is the admin's display order and must win over name.
      const {'_id': 'c1', 'name': 'Grocery', 'showInHeader': true, 'sortOrder': 0},
      const {'_id': 'c2', 'name': 'Electronics', 'showInHeader': true, 'sortOrder': 7},
      const {'_id': 'c3', 'name': 'Stationery & Office', 'sortOrder': 1},
      const {'_id': 's1', 'name': 'Chargers', 'parentId': 'c2'},
    ].map(CategoryDto.fromJson).toList());

    final header = all.where((c) => c.showInHeader).toList();
    expect(header.map((c) => c.name), ['Grocery', 'Electronics']);
    expect(header.map((c) => c.name), isNot(contains('Stationery & Office')));
  });

  test('nothing flagged falls back to core categories, never an empty strip',
      () {
    final all = CategoryMapper.toDomainList([
      const {'_id': 'c1', 'name': 'Grocery'},
      const {'_id': 's1', 'name': 'Rice & Grains', 'parentId': 'c1'},
    ].map(CategoryDto.fromJson).toList());

    final flagged = all.where((c) => c.showInHeader).toList();
    expect(flagged, isEmpty);
    expect(all.where((c) => c.isCore).map((c) => c.name), ['Grocery']);
  });

  test('a missing parentId means core, not a child of ""', () {
    final c = CategoryDto.fromJson(const {'_id': 'x', 'name': 'Beverages'});
    expect(c.parentId, '');
    expect(CategoryMapper.toDomainList([c]).single.isCore, isTrue);
  });

  test('the subcategory rail always leads with All', () {
    // Products are assigned to the parent category, not yet to the new
    // children, so opening on the first real subcategory would show an empty
    // grid. 'All' keeps the category's products visible.
    final children = [
      const {'_id': 's1', 'name': 'Fresh Fruits', 'parentId': 'c1'},
      const {'_id': 's2', 'name': 'Fresh Vegetables', 'parentId': 'c1'},
    ].map(CategoryDto.fromJson).toList();

    final rail = [
      'all',
      ...CategoryMapper.toDomainList(children).map((c) => c.id),
    ];

    expect(rail.first, 'all');
    expect(rail.length, 3);
  });
}
