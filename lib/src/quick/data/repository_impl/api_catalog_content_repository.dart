import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../../domain/model/banner.dart';
import '../../domain/model/cms_page.dart';
import '../../domain/model/sale_campaign.dart';
import '../../domain/repository/catalog_content_repository.dart';
import '../dto/banner_dto.dart';
import '../dto/json_reader.dart';
import '../mapper/banner_mapper.dart';
import 'api_paths.dart';
import '../../../di/fee_settings_providers.dart' show parseTipPresets;
import '../../../shared/widgets/tip_your_driver_card.dart' show kDefaultTipPresets;

class ApiCatalogContentRepository implements CatalogContentRepository {
  ApiCatalogContentRepository(this._client, {String? Function()? zoneId})
      : _zoneId = zoneId ?? _noZone;

  final ApiClient _client;

  /// The zone serving the shopper, read fresh on each call. Sending no zone
  /// asks for the unfiltered catalogue.
  final String? Function() _zoneId;

  static String? _noZone() => null;

  Map<String, dynamic> get _zoneQuery {
    final id = _zoneId();
    return (id == null || id.isEmpty) ? const {} : {'zoneId': id};
  }


  @override
  Future<List<PromoBanner>> heroBanners() => _banners(ApiPaths.heroBanners);

  @override
  Future<List<PromoBanner>> topBanners() => _banners(ApiPaths.topBanners);

  @override
  Future<List<PromoBanner>> promotionBanners() =>
      _banners(ApiPaths.promotionBanners);

  /// Every live campaign: the default plus one per header category.
  ///
  /// Fetched in one call so switching category is instant — a per-tap request
  /// would put a network round trip in the middle of the theme transition.
  @override
  Future<List<SaleCampaign>> martSaleCampaigns() async {
    AppLogger.debug('GET ${ApiPaths.martSaleCampaign}', scope: 'campaign');
    try {
      final json = await _client.get(ApiPaths.martSaleCampaign, query: _zoneQuery);
      if (json is! Map<String, dynamic>) return const [];
      final list = json['campaigns'];
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(SaleCampaign.fromJson)
            .toList();
      }
      // Older backend shape: a single campaign object.
      return [SaleCampaign.fromJson(json)];
    } catch (e) {
      // A promotion failing to load must never take the home screen with it.
      AppLogger.debug('campaign fetch failed: $e', scope: 'campaign');
      return const [];
    }
  }

  Future<List<PromoBanner>> _banners(String path) async {
    AppLogger.debug('GET $path', scope: 'banners');
    try {
      final json = await _client.get(path);
      if (json is! Map<String, dynamic>) {
        AppLogger.debug(
          'GET $path — unexpected payload ${json.runtimeType}',
          scope: 'banners',
        );
        return const [];
      }

      final raw = json.objects('banners');
      final banners = BannerMapper.toDomainList(
        raw.map(BannerDto.fromJson).toList(),
      );
      AppLogger.debug(
        '$path → ${raw.length} raw, ${banners.length} usable '
        '(${raw.length - banners.length} dropped for a missing image)',
        scope: 'banners',
      );
      for (final banner in banners) {
        AppLogger.debug('  ${banner.id} → ${banner.imageUrl}', scope: 'banners');
      }
      return banners;
    } catch (e, stack) {
      AppLogger.error('GET $path failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<CmsPage?> page(String key) async {
    final json = await _client.get(ApiPaths.page(key));
    if (json is! Map<String, dynamic>) return null;
    // `about` uses appName/description, legal keys use title/content.
    final title = json.str('title').isEmpty
        ? json.str('appName')
        : json.str('title');
    final content = json.str('content').isEmpty
        ? json.str('description')
        : json.str('content');
    final page = CmsPage(
      title: title,
      content: content,
      version: json.str('version'),
      email: json.str('email'),
      mobile: json.str('mobile'),
    );
    return page.isEmpty && page.version.isEmpty ? null : page;
  }

  @override
  Future<String> storeName() async {
    final json = await _client.get(ApiPaths.businessSettings);
    if (json is! Map<String, dynamic>) return '';
    // The payload is sometimes the settings document itself and sometimes
    // wrapped; read whichever carries the name.
    final settings = json.mapOrNull('businessSettings') ?? json;
    return settings.str('companyName').trim();
  }

  @override
  Future<({double freeDeliveryThreshold, double baseDeliveryFee, List<double> tipPresets})>
      feeSettings() async {
    final json = await _client.get(ApiPaths.feeSettings);
    final settings =
        json is Map<String, dynamic> ? json.mapOrNull('feeSettings') : null;
    // Zero means "no free-delivery offer", which is what the UI needs to hide
    // the progress bar rather than show a target nobody set.
    if (settings == null) {
      return (
        freeDeliveryThreshold: 0.0,
        baseDeliveryFee: 0.0,
        tipPresets: kDefaultTipPresets,
      );
    }

    // `freeDeliveryThreshold` is now a real admin-panel field. It used to be
    // guessed from a zero-fee band in the distance-banded fee table, falling
    // back to a compiled-in 199 — so the cart promised free delivery at a
    // number no one had configured.
    return (
      freeDeliveryThreshold: settings.dbl('freeDeliveryThreshold'),
      baseDeliveryFee: settings.dbl('deliveryFee'),
      // Same admin field the Food cart reads, scoped to the quick vertical.
      tipPresets: parseTipPresets(settings['tipPresets']),
    );
  }
}
