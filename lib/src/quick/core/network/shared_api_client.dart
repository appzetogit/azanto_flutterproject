import '../../../core/error/failures.dart' as shared;
import '../../../core/network/api_client.dart' as shared;
import '../errors/app_exception.dart';
import '../utils/logger.dart';
import 'api_client.dart';

/// Bridges the quick-commerce module onto the app-wide [shared.ApiClient]:
/// one Dio instance, one encrypted token store, one single-flight 401 refresh
/// for both verticals. Replaces the standalone `DioApiClient` the module
/// shipped with before the Azanto merge.
class SharedApiClient implements ApiClient {
  SharedApiClient(this._inner);

  final shared.ApiClient _inner;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool requiresAuth = false,
  }) =>
      _run(
        () => _inner.get<dynamic>(path, query: query, auth: requiresAuth),
        path,
      );

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool requiresAuth = false,
  }) =>
      _run(() => _inner.post<dynamic>(path, body: body, query: query, auth: requiresAuth));

  @override
  Future<dynamic> patch(String path, {Object? body, bool requiresAuth = false}) =>
      _run(() => _inner.patch<dynamic>(path, body: body, auth: requiresAuth));

  @override
  Future<dynamic> put(String path, {Object? body, bool requiresAuth = false}) =>
      _run(() => _inner.put<dynamic>(path, body: body, auth: requiresAuth));

  @override
  Future<dynamic> delete(String path, {Object? body, bool requiresAuth = false}) =>
      _run(() => _inner.delete<dynamic>(path, body: body, auth: requiresAuth));

  /// Every quick-commerce read is logged with the row count it produced.
  /// An endpoint returning 200-with-nothing is the failure mode that looks
  /// identical to a broken screen, so the count is the useful part.
  Future<dynamic> _run(Future<dynamic> Function() call, [String? path]) async {
    try {
      final result = await call();
      if (path != null) {
        AppLogger.debug('GET $path -> ${_describe(result)}', scope: 'quick.api');
      }
      return result;
    } on shared.Failure catch (f) {
      if (path != null) {
        AppLogger.debug('GET $path FAILED: ${f.message}', scope: 'quick.api');
      }
      throw _map(f);
    }
  }

  String _describe(dynamic body) {
    if (body is List) return '${body.length} item(s)';
    if (body is Map) {
      final counts = <String>[
        for (final e in body.entries)
          if (e.value is List) '${e.key}=${(e.value as List).length}',
      ];
      return counts.isEmpty ? 'keys: ${body.keys.take(5).join(',')}' : counts.join(' ');
    }
    return body == null ? 'null' : body.runtimeType.toString();
  }

  /// Shared-client [shared.Failure]s → this module's [AppException]s, so every
  /// repository and provider keeps the error semantics it was written against.
  AppException _map(shared.Failure f) {
    final message = _storeTerms(f.message);
    if (f is shared.NetworkFailure) return NetworkException(message);
    if (f is shared.TimeoutFailure) return TimeoutException(message);
    if (f is shared.AuthFailure) return UnauthorizedException(message);
    if (f is shared.NotFoundFailure) return NotFoundException(message);
    if (f is shared.ValidationFailure) return ValidationException(message);
    if (f is shared.RateLimitFailure) return ValidationException(message, statusCode: 429);
    if (f is shared.ServerFailure) return ServerException(message, statusCode: f.statusCode);
    return UnknownException(message);
  }

  /// The backend copy says "Restaurant" where this vertical brands every
  /// seller a "Store" — rewrite once, here, so screens never disagree.
  static String _storeTerms(String message) => message
      .replaceAll('Restaurants', 'Stores')
      .replaceAll('Restaurant', 'Store')
      .replaceAll('restaurants', 'stores')
      .replaceAll('restaurant', 'store');
}
