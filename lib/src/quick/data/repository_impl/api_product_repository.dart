import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../domain/model/addon.dart';
import '../../domain/model/brand.dart';
import '../../domain/model/paged_result.dart';
import '../../domain/model/product.dart';
import '../../domain/model/seller.dart';
import '../../core/network/media_url.dart';
import '../../core/utils/logger.dart';
import '../../domain/repository/product_repository.dart';
import '../../domain/service/catalog_grouping_service.dart';
import '../dto/addon_dto.dart';
import '../dto/json_reader.dart';
import '../dto/product_dto.dart';
import '../mapper/addon_mapper.dart';
import '../mapper/product_mapper.dart';
import 'api_paths.dart';

class ApiProductRepository implements ProductRepository {
  ApiProductRepository(
    this._client, {
    CatalogGroupingService? grouping,
    String? Function()? zoneId,
  })  : _grouping = grouping ?? const CatalogGroupingService(),
        _zoneId = zoneId ?? _noZone;

  final ApiClient _client;
  final CatalogGroupingService _grouping;

  /// The zone serving the shopper, read fresh on each call so changing address
  /// takes effect without rebuilding the repository. Mart stock is zone-scoped;
  /// sending no zone asks for the unfiltered catalogue, which is what a shopper
  /// with no address set should still see.
  final String? Function() _zoneId;

  static String? _noZone() => null;

  /// Query fragment every catalogue read carries.
  Map<String, dynamic> get _zoneQuery {
    final id = _zoneId();
    return (id == null || id.isEmpty) ? const {} : {'zoneId': id};
  }

  /// Brands are derived from the catalog, which is expensive to re-scan; the
  /// result is stable for a session, so it is cached here.
  List<Brand>? _brandCache;

  @override
  Future<PagedResult<Product>> list({
    String? query,
    String? categoryId,
    bool vegOnly = false,
    bool inStockOnly = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await _client.get(
      ApiPaths.searchProducts,
      query: {
        ..._zoneQuery,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
        if (vegOnly) 'isVeg': 'true',
        if (inStockOnly) 'inStockOnly': 'true',
        'page': page,
        // The endpoint caps `limit` at 50.
        'limit': pageSize > 50 ? 50 : pageSize,
      },
    );

    return _toPage(json);
  }

  @override
  Future<PagedResult<Product>> search({
    required String query,
    ProductFilters filters = const ProductFilters(),
    int page = 1,
    int pageSize = 20,
  }) =>
      list(
        query: query,
        categoryId: filters.categoryId,
        vegOnly: filters.vegOnly,
        inStockOnly: filters.inStockOnly,
        page: page,
        pageSize: pageSize,
      );

  @override
  Future<Product> getById(String id, {String? sellerId}) async {
    // The backend exposes no single-item endpoint. When we know the seller we
    // read its menu (which carries mrp/stock/packSize); otherwise we fall back
    // to scanning the paginated catalog. Documented in README → Backend Gaps.
    if (sellerId != null && sellerId.isNotEmpty) {
      final found = await _fromSellerMenu(sellerId, id);
      if (found != null) return found;
    }

    for (var page = 1; page <= 4; page++) {
      final result = await list(page: page, pageSize: 50);
      for (final product in result.items) {
        if (product.id == id) return product;
      }
      if (!result.hasMore) break;
    }

    throw const NotFoundException('This product is no longer available.');
  }

  Future<Product?> _fromSellerMenu(String sellerId, String productId) async {
    final items = await bySeller(sellerId);
    for (final product in items) {
      if (product.id == productId) return product;
    }
    return null;
  }

  @override
  Future<List<Product>> bySeller(String sellerId) async {
    if (sellerId.isEmpty) return const [];
    final json = await _client.get(ApiPaths.sellerMenu(sellerId));
    if (json is! Map<String, dynamic>) return const [];

    // The menu is the only endpoint that lists one seller's catalogue —
    // `/search/products` has no seller filter. It returns everything at once,
    // so there is no page to follow.
    return [
      for (final section in json.mapAt('menu').objects('sections'))
        for (final item in section.objects('items'))
          ProductMapper.toDomain(
            ProductDto.fromJson({...item, 'restaurantId': sellerId}),
          ),
    ];
  }

  @override
  Future<List<AddonGroup>> addonsFor({
    required String sellerId,
    String? productId,
  }) async {
    if (sellerId.isEmpty) return const [];
    final json = await _client.get(
      ApiPaths.sellerAddons(sellerId),
      query: {if (productId != null && productId.isNotEmpty) 'foodId': productId},
    );
    if (json is! Map<String, dynamic>) return const [];

    return AddonMapper.groupsToDomain(
      json.objects('groups').map(AddonGroupDto.fromJson).toList(),
    );
  }

  @override
  Future<List<Brand>> brands({String? categoryId}) async {
    if (categoryId != null && categoryId.isNotEmpty) {
      final page = await list(categoryId: categoryId, pageSize: 50);
      return _grouping.brandsFrom(page.items);
    }

    final cached = _brandCache;
    if (cached != null) return cached;

    final products = <Product>[];
    for (var page = 1; page <= 3; page++) {
      final result = await list(page: page, pageSize: 50);
      products.addAll(result.items);
      if (!result.hasMore) break;
    }

    return _brandCache = _grouping.brandsFrom(products);
  }

  @override
  Future<List<Seller>> sellers({int limit = 20}) async {
    final json = await _client.get(
      ApiPaths.sellers,
      query: {..._zoneQuery, 'limit': limit},
    );
    if (json is! Map<String, dynamic>) {
      AppLogger.debug('sellers: unexpected payload ${json.runtimeType}', scope: 'quick.api');
      return const [];
    }

    final rows = json.objects('restaurants');
    AppLogger.debug('GET ${ApiPaths.sellers} -> ${rows.length} seller(s)', scope: 'quick.api');

    return [
      for (final r in rows)
        Seller(
          id: r.str('_id', r.str('id')),
          name: r.str('restaurantName', r.str('name')),
          imageUrl: MediaUrl.resolve(r.str('profileImage', r.str('coverImage'))),
          // The backend flag is authoritative: a store that is not accepting
          // orders is shown closed rather than hidden, so the catalogue does
          // not silently shrink.
          acceptingOrders: r.boolean('isAcceptingOrders'),
          deliveryMinutes: (r['estimatedDeliveryTimeMinutes'] as num?)?.toInt(),
          rating: (r['rating'] as num?)?.toDouble() ?? 0,
          ratingCount: r.integer('totalRatings'),
          isVerified: r.boolean('isVerified'),
          locality: r.str('area', r.str('city')),
          // Product count is unknown from this endpoint; the card falls back to
          // its own copy rather than claiming a number we have not counted.
          productCount: 0,
        ),
    ];
  }

  PagedResult<Product> _toPage(dynamic json) {
    if (json is! Map<String, dynamic>) return PagedResult.empty<Product>();

    final dtos = json.objects('products').map(ProductDto.fromJson).toList();
    final meta = PageMeta.from(json, fallbackCount: dtos.length);

    return PagedResult(
      items: ProductMapper.toDomainList(dtos),
      total: meta.total,
      page: meta.page,
      pageSize: meta.pageSize,
    );
  }
}
