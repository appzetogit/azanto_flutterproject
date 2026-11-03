import '../../core/network/api_client.dart';
import '../../domain/model/category.dart';
import '../../domain/model/sub_category.dart';
import '../../domain/repository/category_repository.dart';
import '../../domain/repository/product_repository.dart';
import '../../domain/service/catalog_grouping_service.dart';
import '../dto/category_dto.dart';
import '../dto/json_reader.dart';
import '../mapper/category_mapper.dart';
import 'api_paths.dart';

class ApiCategoryRepository implements CategoryRepository {
  ApiCategoryRepository(
    this._client, {
    required ProductRepository productRepository,
    CatalogGroupingService? grouping,
    String? Function()? zoneId,
  })  : _products = productRepository,
        _grouping = grouping ?? const CatalogGroupingService(),
        _zoneId = zoneId ?? _noZone;

  final ApiClient _client;
  final ProductRepository _products;
  final CatalogGroupingService _grouping;

  /// The zone serving the shopper, read fresh on each call. Sending no zone
  /// asks for the unfiltered catalogue.
  final String? Function() _zoneId;

  static String? _noZone() => null;

  Map<String, dynamic> get _zoneQuery {
    final id = _zoneId();
    return (id == null || id.isEmpty) ? const {} : {'zoneId': id};
  }

  @override
  Future<List<Category>> topLevel() async => all().then(
        (all) => all.where((c) => c.isCore).toList(),
      );

  /// Every category the endpoint returns, both levels.
  ///
  /// The response is a flat list with a `parentId` on each row, so the two
  /// levels are separated here rather than in two requests. Cached per call
  /// only — the caller decides how long to hold it.
  @override
  Future<List<Category>> all() async {
    // Zone-scoped: the category list is the same everywhere, but each
    // row's `itemCount` must count only stock the shopper can buy.
    final json = await _client.get(ApiPaths.adminCategories, query: _zoneQuery);
    if (json is! Map<String, dynamic>) return const [];
    return CategoryMapper.toDomainList(
      json.objects('categories').map(CategoryDto.fromJson).toList(),
    );
  }

  @override
  Future<List<SubCategory>> subCategoriesOf(String categoryId) async {
    // Real children now that categories carry a parentId. This used to derive
    // sub-categories from the brands present in a category's items, which meant
    // an empty category had none and the names were brand names rather than the
    // admin's own ('Chargers', 'Cables', …).
    final children = await all().then(
      (all) => all.where((c) => c.parentId == categoryId).toList(),
    );
    if (children.isNotEmpty) {
      return [
        // Same leading 'All' the brand-derived grouping produces. Without it the
        // rail opens on the first real subcategory and shows nothing, because
        // products are still assigned to the parent category rather than to
        // these newly created children.
        SubCategory(id: 'all', name: 'All', parentCategoryId: categoryId),
        ...children.map((c) => SubCategory(
              id: c.id,
              name: c.name,
              parentCategoryId: categoryId,
              imageUrl: c.imageUrl,
            )),
      ];
    }

    // Categories that predate the parent/child tree still have no children;
    // fall back to the old brand-derived grouping so they do not go blank.
    final page = await _products.list(categoryId: categoryId, pageSize: 50);
    return _grouping.subCategoriesFrom(page.items, categoryId);
  }
}
