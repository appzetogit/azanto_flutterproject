/// Key–value persistence abstraction. Callers never see shared_preferences.
abstract interface class LocalStorage {
  String? getString(String key);
  Future<void> setString(String key, String value);

  bool? getBool(String key);
  Future<void> setBool(String key, bool value);

  List<String> getStringList(String key);
  Future<void> setStringList(String key, List<String> value);

  Future<void> remove(String key);
}

/// Every persisted key in one place — avoids silent typos across features.
abstract final class StorageKeys {
  static const accessToken = 'auth.access_token';
  static const refreshToken = 'auth.refresh_token';
  static const userJson = 'auth.user';
  static const onboardingSeen = 'app.onboarding_seen';
  static const themeMode = 'app.theme_mode';
  /// Versioned: the brand moved from yellow to teal, and a value stored under
  /// the old key would pin existing installs to the retired palette forever —
  /// the theme picker defaults only apply when nothing is stored. Bumping the
  /// key retires those saved choices once, so everyone lands on the current
  /// brand; picking a flavour again persists under this key.
  static const themeFlavor = 'app.theme_flavor.v2';
  static const selectedAddressId = 'app.selected_address_id';
  static const recentSearches = 'search.recent';
  static const recentlyViewed = 'catalog.recently_viewed';
  /// Resolved Places `details()` results, most-recent-first, capped — lets a
  /// repeat address pick skip a billed Places Details call entirely.
  static const placeDetailsCache = 'places.details_cache';
  static const cachedCart = 'cart.cached';
  static const notificationsEnabled = 'settings.notifications';
}
