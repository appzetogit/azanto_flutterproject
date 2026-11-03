/// A catalog category. Sourced from the admin-curated category list.
class Category {
  const Category({
    required this.id,
    required this.name,
    this.imageUrl = '',
    this.sortOrder = 0,
    this.parentId = '',
    this.showInHeader = false,
    this.foodTypeScope = '',
    this.itemCount = 0,
  });

  final String id;
  final String name;
  final String imageUrl;
  final int sortOrder;

  /// Parent category id; empty for a core (top-level) category.
  ///
  /// The header shows core categories only. Without this the app rendered every
  /// row the endpoint returned, so seeding 122 subcategories put all of them in
  /// the header strip.
  final String parentId;

  bool get isCore => parentId.isEmpty;

  /// Whether the admin put this in the header strip. The header shows a short
  /// curated set, not every core category, so this is a separate decision from
  /// [isCore].
  final bool showInHeader;
  final String foodTypeScope;
  final int itemCount;

  @override
  bool operator ==(Object other) => other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
