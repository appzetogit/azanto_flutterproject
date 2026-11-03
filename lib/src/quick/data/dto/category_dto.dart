import 'json_reader.dart';

/// From `GET /food/search/categories/admin` (and the public category list,
/// which uses the same serializer).
class CategoryDto {
  const CategoryDto({
    required this.id,
    required this.name,
    this.image = '',
    this.sortOrder = 0,
    this.parentId = '',
    this.showInHeader = false,
    this.foodTypeScope = '',
    this.itemCount = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String image;
  final int sortOrder;

  /// Parent category id, empty for a top-level ('core') category.
  final String parentId;

  /// Admin-curated: whether this belongs in the app's core header strip.
  final bool showInHeader;
  final String foodTypeScope;

  /// Sellable products in this category, children included. Counted by the
  /// backend — the tile's "+N more" badge is a real number or it is not shown.
  final int itemCount;

  final bool isActive;

  factory CategoryDto.fromJson(Map<String, dynamic> json) => CategoryDto(
        id: json.id(),
        name: json.str('name'),
        image: json.imageUrl('image'),
        sortOrder: json.integer('sortOrder'),
        parentId: json.str('parentId'),
        showInHeader: json.boolean('showInHeader', false),
        foodTypeScope: json.str('foodTypeScope'),
        itemCount: json.integer('itemCount'),
        isActive: json.boolean('isActive', true),
      );
}
