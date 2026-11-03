class Store99Cuisine {
  final String id;
  final String label;
  final String imagesPath;

  /// The term the catalogue filter matches on.
  ///
  /// `/public/foods?categorySlug=` regex-matches a food's name and
  /// categoryName, so it needs a WORD ('idli', 'dosa') — not the category's
  /// ObjectId, which matches nothing and returned an empty screen for every
  /// chip. Kept separate from [id] so selection identity stays the real id.
  final String slug;

  const Store99Cuisine({
    required this.id,
    required this.label,
    required this.imagesPath,
    this.slug = '',
  });
}
