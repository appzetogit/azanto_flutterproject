import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/utils/maps_debug.dart';
import '../../core/config/app_config.dart';
import '../../core/local_storage/local_storage.dart';
import '../../core/utils/logger.dart';
import '../../domain/model/place.dart';
import '../../domain/repository/place_repository.dart';
import '../dto/json_reader.dart';

/// Google Places + Geocoding over REST.
///
/// Deliberately uses its own [Dio] rather than the app's `ApiClient`: that
/// client is bound to the Azanto backend's base URL, auth header and
/// `{success, message, data}` envelope, none of which apply to Google.
///
/// The key comes from [AppConfig], which reads it from `config/keys.env` — the
/// same file the Android manifest and iOS xcconfig read.
class GooglePlaceRepository implements PlaceRepository {
  GooglePlaceRepository(this._config, this._storage)
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://maps.googleapis.com/maps/api',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            validateStatus: (_) => true,
          ),
        );

  final AppConfig _config;
  final LocalStorage _storage;
  final Dio _dio;

  static const _detailsCacheCap = 20;

  /// Keyed by `"<query>|<lat>|<lng>"` — cleared per editing session in
  /// [endSession] so a stale location bias never lingers into the next one.
  final _autocompleteMemo = <String, List<PlaceSuggestion>>{};

  /// Reverse-geocode results, keyed by coordinates rounded to ~11 m.
  ///
  /// Several callers resolve the same position independently — the coords
  /// provider, the "near you" refresh, the permission screen — and each one was
  /// a separate billed Geocoding call for a string that is identical at this
  /// resolution. Deliberately in-memory and session-scoped rather than written
  /// to disk, which keeps it plainly within the temporary-caching allowance in
  /// the Google Maps Platform terms.
  final _reverseMemo = <String, ResolvedPlace>{};
  static const _reverseMemoCap = 50;

  /// Logged once, not per call — a missing key fails on every keystroke.
  bool _warnedAboutKey = false;

  /// True when the Dart-side key is present. The map widget does not need it
  /// (the SDK reads a native key from the manifest / Info.plist), so a build
  /// without `--dart-define-from-file=config/keys.env` draws a perfectly good
  /// map while every Places and Geocoding call here returns nothing.
  bool get _hasKey {
    if (_config.hasMapsKey) return true;
    if (!_warnedAboutKey) {
      _warnedAboutKey = true;
      AppLogger.error(
        'MAPS_API_KEY is empty on the Dart side — Places search and reverse '
        'geocoding are disabled. Run with '
        '--dart-define-from-file=config/keys.env.',
      );
    }
    return false;
  }

  /// Keeps autocomplete requests for one editing session on a single billing
  /// session token, which is materially cheaper than billing each keystroke.
  String? _sessionToken;

  void startSession(String token) => _sessionToken = token;
  void endSession() {
    _sessionToken = null;
    _autocompleteMemo.clear();
  }

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];

    // Covers a user backspacing back to a query they already typed in this
    // same session — a real, if minor, source of duplicate billed calls.
    final memoKey = '${trimmed.toLowerCase()}|$latitude|$longitude';
    final memoized = _autocompleteMemo[memoKey];
    if (memoized != null) return memoized;

    if (!_hasKey) return const [];

    final json = await _get('/place/autocomplete/json', {
      'input': trimmed,
      'key': _config.mapsApiKey,
      'components': 'country:in',
      if (_sessionToken != null) 'sessiontoken': _sessionToken,
      if (latitude != null && longitude != null) ...{
        'location': '$latitude,$longitude',
        'radius': '30000',
      },
    });
    if (json == null) return const [];

    final suggestions = json.objects('predictions').map((p) {
      final formatting = p.mapAt('structured_formatting');
      return PlaceSuggestion(
        placeId: p.str('place_id'),
        primaryText: formatting.str('main_text', p.str('description')),
        secondaryText: formatting.str('secondary_text'),
      );
    }).where((s) => s.placeId.isNotEmpty).toList();

    _autocompleteMemo[memoKey] = suggestions;
    return suggestions;
  }

  @override
  Future<ResolvedPlace?> details(String placeId) async {
    if (placeId.isEmpty) return null;

    // A place the user already resolved (their own repeat picks — "Home",
    // "Work", etc.) skips the Details call entirely, which is the pricier of
    // the two Places SKUs.
    final cached = await _cachedDetails(placeId);
    if (cached != null) {
      endSession();
      return cached;
    }

    if (!_hasKey) return null;

    final json = await _get('/place/details/json', {
      'place_id': placeId,
      'key': _config.mapsApiKey,
      'fields': 'geometry,formatted_address,address_component,name',
      if (_sessionToken != null) 'sessiontoken': _sessionToken,
    });
    if (json == null) return null;

    // The session ends with the details call — that is what Google bills as one
    // unit. Holding the token open past it would be charged per request.
    endSession();

    final result = json.mapOrNull('result');
    if (result == null) return null;

    final place = _toPlace(result);
    await _cacheDetails(placeId, place);
    return place;
  }

  Future<ResolvedPlace?> _cachedDetails(String placeId) async {
    for (final entry in _storage.getStringList(StorageKeys.placeDetailsCache)) {
      final map = jsonDecode(entry) as Map<String, dynamic>;
      if (map['placeId'] == placeId) return _placeFromCacheJson(map);
    }
    return null;
  }

  Future<void> _cacheDetails(String placeId, ResolvedPlace place) async {
    final entries = List<String>.from(
      _storage.getStringList(StorageKeys.placeDetailsCache),
    )..removeWhere(
        (entry) => (jsonDecode(entry) as Map<String, dynamic>)['placeId'] == placeId,
      );
    entries.insert(0, jsonEncode(_placeToCacheJson(placeId, place)));
    if (entries.length > _detailsCacheCap) {
      entries.removeRange(_detailsCacheCap, entries.length);
    }
    await _storage.setStringList(StorageKeys.placeDetailsCache, entries);
  }

  Map<String, dynamic> _placeToCacheJson(String placeId, ResolvedPlace p) => {
        'placeId': placeId,
        'latitude': p.latitude,
        'longitude': p.longitude,
        'formattedAddress': p.formattedAddress,
        'name': p.name,
        'subLocality': p.subLocality,
        'locality': p.locality,
        'city': p.city,
        'state': p.state,
        'postalCode': p.postalCode,
        'streetLine': p.streetLine,
        'country': p.country,
      };

  ResolvedPlace _placeFromCacheJson(Map<String, dynamic> j) => ResolvedPlace(
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        formattedAddress: j['formattedAddress'] as String? ?? '',
        name: j['name'] as String? ?? '',
        subLocality: j['subLocality'] as String? ?? '',
        locality: j['locality'] as String? ?? '',
        city: j['city'] as String? ?? '',
        state: j['state'] as String? ?? '',
        postalCode: j['postalCode'] as String? ?? '',
        streetLine: j['streetLine'] as String? ?? '',
        country: j['country'] as String? ?? '',
      );

  @override
  Future<ResolvedPlace?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final memoKey = '${latitude.toStringAsFixed(4)},'
        '${longitude.toStringAsFixed(4)}';
    final memoized = _reverseMemo[memoKey];
    if (memoized != null) return memoized;

    if (!_hasKey) return null;

    final json = await _get('/geocode/json', {
      'latlng': '$latitude,$longitude',
      'key': _config.mapsApiKey,
    });
    if (json == null) return null;

    final results = json.objects('results');
    if (results.isEmpty) return null;

    // Results run most-specific first, which is the one worth showing.
    final place =
        _toPlace(results.first, fallbackLat: latitude, fallbackLng: longitude);

    if (_reverseMemo.length >= _reverseMemoCap) {
      _reverseMemo.remove(_reverseMemo.keys.first);
    }
    _reverseMemo[memoKey] = place;
    return place;
  }

  @override
  Future<ResolvedPlace?> geocodeAddress(String address) async {
    final query = address.trim();
    if (!_hasKey || query.isEmpty) return null;

    final json = await _get('/geocode/json', {
      'address': query,
      'components': 'country:IN',
      'key': _config.mapsApiKey,
    });
    if (json == null) return null;

    final results = json.objects('results');
    if (results.isEmpty) return null;

    return _toPlace(results.first);
  }

  Future<Map<String, dynamic>?> _get(
    String path,
    Map<String, dynamic> query,
  ) async {
    // Single chokepoint for every billed Google call this repository makes, so
    // a duplicate or runaway caller shows up in the console. The key lives in
    // `query` and is deliberately never logged.
    mapsDebug(
      path.contains('geocode') ? 'GEOCODING REQUEST' : 'PLACES REQUEST',
      path,
    );
    try {
      final response = await _dio.get<dynamic>(path, queryParameters: query);
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;

      final status = data.str('status');
      if (status == 'OK' || status == 'ZERO_RESULTS') return data;

      // REQUEST_DENIED almost always means the API is not enabled on the key or
      // billing is off — worth naming, because the symptom is a silent empty list.
      AppLogger.error(
        'Google $path failed: $status ${data.str('error_message')}',
      );
      return null;
    } on DioException catch (e) {
      AppLogger.error('Google $path unreachable', error: e);
      return null;
    }
  }

  ResolvedPlace _toPlace(
    Map<String, dynamic> json, {
    double? fallbackLat,
    double? fallbackLng,
  }) {
    final location = json.mapAt('geometry').mapAt('location');
    final components = json.objects('address_components');

    String component(String type) {
      for (final c in components) {
        if (c.strings('types').contains(type)) return c.str('long_name');
      }
      return '';
    }

    final streetNumber = component('street_number');
    final route = component('route');

    return ResolvedPlace(
      latitude: location.doubleOrNull('lat') ?? fallbackLat ?? 0,
      longitude: location.doubleOrNull('lng') ?? fallbackLng ?? 0,
      formattedAddress: json.str('formatted_address'),
      name: json.str('name'),
      subLocality: component('sublocality_level_1').isNotEmpty
          ? component('sublocality_level_1')
          : component('sublocality'),
      locality: component('locality'),
      city: component('locality').isNotEmpty
          ? component('locality')
          : component('administrative_area_level_2'),
      state: component('administrative_area_level_1'),
      postalCode: component('postal_code'),
      streetLine: [streetNumber, route].where((p) => p.isNotEmpty).join(' '),
      country: component('country'),
    );
  }
}
