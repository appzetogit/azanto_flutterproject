import 'dart:convert';

import '../../../src/core/network/api_client.dart';
import '../../../src/core/storage/token_storage.dart';

/// Taxi's view of the session. Azanto has ONE login: the food auth issues the
/// JWT and the backend's taxi middleware accepts it for the same `users`
/// account, so taxi reads the food token and refreshes through food's client.
class SecureStorageService {
  SecureStorageService(this._tokens, this._api);

  final TokenStorage _tokens;
  final ApiClient _api;

  Future<String?> readToken() => _tokens.accessToken;

  /// Single-flight refresh shared with the food side. True when a new access
  /// token was stored.
  Future<bool> refresh() => _api.refreshSession();

  /// The current token, refreshed first if it expires within 30s. For the
  /// socket handshake, which has no 401-and-retry path of its own.
  Future<String?> validToken() async {
    final token = await readToken();
    if (token == null || token.isEmpty) return token;
    final exp = _expiry(token);
    if (exp != null && exp.isBefore(DateTime.now().add(const Duration(seconds: 30)))) {
      await refresh();
      return readToken();
    }
    return token;
  }

  static DateTime? _expiry(String jwt) {
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(jwt.split('.')[1]))),
      );
      final exp = payload['exp'];
      return exp is num
          ? DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000)
          : null;
    } catch (_) {
      return null;
    }
  }

  // Sign-in and sign-out belong to the food auth (see TaxiSection.openLogin /
  // signOut); taxi never writes or deletes the shared token itself.
  Future<void> saveToken(String token) async {}
  Future<void> deleteToken() async {}
  Future<void> clearAll() async {}
}
