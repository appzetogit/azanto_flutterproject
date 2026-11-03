/// One tile under the Mart sale banner.
class SaleCampaignTile {
  const SaleCampaignTile({
    required this.title,
    this.badgeText = '',
    this.emojis = '',
    this.imageUrl = '',
    this.categoryId,
  });

  final String title;
  final String badgeText;
  final String emojis;
  final String imageUrl;

  /// A real category id, or null when the admin has not linked one — the tile
  /// then renders but does not navigate, rather than pushing a dead route.
  final String? categoryId;

  factory SaleCampaignTile.fromJson(Map<String, dynamic> json) {
    final id = json['categoryId']?.toString();
    return SaleCampaignTile(
      title: json['title']?.toString() ?? '',
      badgeText: json['badgeText']?.toString() ?? '',
      emojis: json['emojis']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      categoryId: (id == null || id.isEmpty) ? null : id,
    );
  }
}

/// One product featured in the campaign's deal card.
///
/// A slim projection of the catalogue item, exactly the fields the campaign
/// endpoint returns — the deal card needs a name, a picture and two prices, not
/// a whole [Product] with variants and seller.
class SaleCampaignProduct {
  const SaleCampaignProduct({
    required this.id,
    required this.name,
    this.imageUrl = '',
    this.price = 0,
    this.mrp,
  });

  final String id;
  final String name;
  final String imageUrl;
  final double price;

  /// Struck-through price. Null when the admin never entered an MRP, in which
  /// case the card shows no strike-through rather than inventing one.
  final double? mrp;

  /// Whole-percent saving, or null when there is nothing to claim.
  int? get discountPercent {
    final was = mrp;
    if (was == null || was <= price || was <= 0) return null;
    return (((was - price) / was) * 100).round();
  }

  static double _toDouble(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  factory SaleCampaignProduct.fromJson(Map<String, dynamic> json) {
    final images = json['images'];
    final image = (json['image'] ?? '').toString().trim();
    final mrp = json['mrp'];
    return SaleCampaignProduct(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      imageUrl: image.isNotEmpty
          ? image
          : (images is List && images.isNotEmpty ? images.first.toString() : ''),
      price: _toDouble(json['price']),
      mrp: mrp == null ? null : _toDouble(mrp),
    );
  }
}

/// The admin-configured Mart promotion behind the sale banner: headline, date
/// strip and tiles.
///
/// Everything here used to be compiled into the app — including a date range
/// that could only be corrected by shipping a release.
class SaleCampaign {
  const SaleCampaign({
    required this.id,
    required this.title,
    this.categoryId,
    this.themeColor = '',
    this.accentColor = '',
    this.searchHint = '',
    this.dateLabel = '',
    this.bannerImageUrl = '',
    this.dealLabel = '',
    this.tiles = const [],
    this.products = const [],
  });

  final String id;
  final String title;

  /// Header category this campaign themes; null is the default shown for 'All'.
  final String? categoryId;

  /// Page background and headline ink, as '#RRGGBB'. Empty means the app keeps
  /// its own palette — a campaign is never required to restyle the page.
  final String themeColor;
  final String accentColor;

  /// Search-bar placeholder for this category, e.g. 'milk' / 'lipstick'.
  final String searchHint;

  /// Already formatted by the backend, which owns the campaign window.
  final String dateLabel;
  final String bannerImageUrl;
  final String dealLabel;
  final List<SaleCampaignTile> tiles;

  /// The products the deal card rotates through, in the admin's own order.
  /// Empty means the app falls back to its existing flash-sale pick.
  final List<SaleCampaignProduct> products;

  factory SaleCampaign.fromJson(Map<String, dynamic> json) {
    final cat = json['categoryId']?.toString();
    return SaleCampaign(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        categoryId: (cat == null || cat.isEmpty) ? null : cat,
        themeColor: json['themeColor']?.toString() ?? '',
        accentColor: json['accentColor']?.toString() ?? '',
        searchHint: json['searchHint']?.toString() ?? '',
        dateLabel: json['dateLabel']?.toString() ?? '',
        bannerImageUrl: json['bannerImageUrl']?.toString() ?? '',
        dealLabel: json['dealLabel']?.toString() ?? '',
        tiles: (json['tiles'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SaleCampaignTile.fromJson)
            .toList(),
        products: (json['products'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SaleCampaignProduct.fromJson)
            .toList(),
      );
  }
}

/// Parses '#RRGGBB' into a colour value, or null when unset/malformed — the
/// caller then keeps the app's own palette rather than rendering black.
int? parseHexColor(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  if (cleaned.length != 6) return null;
  final value = int.tryParse(cleaned, radix: 16);
  return value == null ? null : 0xFF000000 | value;
}
