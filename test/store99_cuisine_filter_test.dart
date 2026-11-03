import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/domain/model/store99_cuisine.dart';

/// Tapping a cuisine chip in the 99 Store showed an empty screen for every
/// category. The chip carried the category's ObjectId, but the catalogue filter
/// (`/public/foods?categorySlug=`) regex-matches a food's name and
/// categoryName — so an id matched nothing at all.
///
/// This pins the shape the chip has to carry: an id for selection identity and
/// a separate word for the query.
void main() {
  test('a chip carries a searchable slug alongside its id', () {
    const chip = Store99Cuisine(
      id: '6a81b8d8cc7e3947d2ad6e5e',
      label: 'Idli',
      imagesPath: '',
      slug: 'Idli',
    );

    expect(chip.id, isNot(chip.slug),
        reason: 'the id is a database key, the slug is a search term');
    expect(chip.slug, 'Idli');
    // An ObjectId as the query term is exactly what returned nothing.
    expect(RegExp(r'^[0-9a-f]{24}$').hasMatch(chip.slug), isFalse);
  });

  test('slug defaults to empty so callers fall back to the label', () {
    const chip = Store99Cuisine(id: 'x', label: 'Dosa', imagesPath: '');
    expect(chip.slug, isEmpty);
  });
}
