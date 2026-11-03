import '../../core/constants/app_constants.dart';

/// Business logic and utility for product deep linking and sharing.
///
/// Follows Clean Architecture guidelines (Domain layer — framework independent).
class DeepLinkService {
  static const String appScheme = 'suvio';

  /// The host shared links are built on.
  ///
  /// Shared links MUST be https, not the suvio:// custom scheme. WhatsApp, SMS,
  /// Instagram and most other chat apps only turn http(s) URLs into tappable
  /// links — a suvio:// URL is delivered as inert plain text, which is exactly
  /// what "the link isn't working" was. https also degrades usefully: a
  /// recipient without the app installed lands on the web page instead of an
  /// error, and the link previews with a title and image.
  ///
  /// Tracks the API host so a staging build shares staging links rather than
  /// silently pointing testers at production.
  static const String webHost = AppConstants.hostUrl;

  /// Deep link to a single dish.
  ///
  /// The path and query deliberately mirror the app's existing `/food-detail`
  /// route, so an incoming link resolves through the same builder as in-app
  /// navigation with no separate parsing path to drift out of sync.
  static String generateProductDeepLink({
    required String productId,
    required String restaurantId,
  }) {
    final query = Uri(
      queryParameters: {
        'id': productId,
        if (restaurantId.isNotEmpty) 'restaurantId': restaurantId,
      },
    ).query;
    return '$webHost/food-detail?$query';
  }

  /// Deep link to a restaurant's page.
  static String generateRestaurantDeepLink({required String restaurantId}) {
    return '$webHost/restaurant-detail/$restaurantId';
  }

  /// Generates human-friendly share text containing product info and the deep link.
  ///
  /// The link goes last and on its own line: chat apps link-detect to the end of
  /// the token, so trailing punctuation or text gets swallowed into the URL and
  /// breaks it.
  static String generateProductShareText({
    required String productName,
    String? restaurantName,
    required String productId,
    required String restaurantId,
  }) {
    final link = generateProductDeepLink(
      productId: productId,
      restaurantId: restaurantId,
    );
    final prefix = (restaurantName != null && restaurantName.isNotEmpty)
        ? 'Check out "$productName" from $restaurantName on Go Azanto!'
        : 'Check out "$productName" on Go Azanto!';
    return '$prefix\n\nOrder now on Go Azanto:\n$link';
  }

  /// Generates human-friendly share text for a restaurant.
  static String generateRestaurantShareText({
    required String restaurantName,
    required String restaurantId,
    String? cuisines,
  }) {
    final link = generateRestaurantDeepLink(restaurantId: restaurantId);
    final descriptor = (cuisines != null && cuisines.isNotEmpty)
        ? '$restaurantName ($cuisines)'
        : restaurantName;
    return 'Check out $descriptor on Go Azanto!\n\nOrder now on Go Azanto:\n$link';
  }

  /// Parses a deep link Uri to extract product ID and restaurant ID.
  ///
  /// Accepts both the https form now shared and the legacy suvio:// form, which
  /// links already sent out in the wild still use. In a custom-scheme URI the
  /// first segment lands in `host` rather than `path`, so both are checked.
  static ({String? productId, String? restaurantId}) parseDeepLink(Uri uri) {
    final path = uri.path;
    if (path == '/food' ||
        path == '/food-detail' ||
        uri.host == 'food' ||
        uri.host == 'food-detail') {
      final id = uri.queryParameters['id'] ?? uri.queryParameters['productId'];
      final rId =
          uri.queryParameters['restaurantId'] ?? uri.queryParameters['rId'];
      return (productId: id, restaurantId: rId);
    }
    return (productId: null, restaurantId: null);
  }

  /// Builds a referral invite link.
  ///
  /// Only used for links this app generates itself; the shared referral link
  /// riders and customers actually send is built server-side from the template
  /// an admin sets in Referral Settings, so that one stays the single source of
  /// truth for the URL. This exists so both ends agree on the shape.
  static String generateReferralLink({required String code}) =>
      '$webHost/refer?ref=${Uri.encodeComponent(code)}';

  /// Pulls a referral code out of an invite link, or null if it is not one.
  ///
  /// `ref` is the documented parameter. `referrer` and `code` are also accepted
  /// because the Play Install Referrer path uses `referrer`, and an admin
  /// hand-writing the link template in the panel tends to reach for `code`.
  ///
  /// Upper-cased on the way out: codes are generated upper-case, and a link
  /// that has been through a chat app's lower-casing would otherwise fail to
  /// match on the server.
  static String? parseReferralCode(Uri uri) {
    final isReferralPath = uri.path.startsWith('/refer') || uri.host == 'refer';
    if (!isReferralPath) return null;

    final q = uri.queryParameters;
    final raw = q['ref'] ?? q['referrer'] ?? q['code'] ?? '';
    final code = raw.trim().toUpperCase();
    return code.isEmpty ? null : code;
  }

  /// Extracts a restaurant id from a restaurant deep link, or null.
  static String? parseRestaurantDeepLink(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments.first == 'restaurant-detail') {
      return segments[1].isEmpty ? null : segments[1];
    }
    // Custom-scheme form: suvio://restaurant-detail/<id>
    if (uri.host == 'restaurant-detail' && segments.isNotEmpty) {
      return segments.first.isEmpty ? null : segments.first;
    }
    return null;
  }
}
