import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';

typedef UnauthorizedCallback = void Function();

class DioClient {
  final Dio dio;
  final SecureStorageService secureStorage;
  UnauthorizedCallback? onUnauthorized;

  DioClient(this.secureStorage)
      : dio = Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await secureStorage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        // Food's access token is short-lived: on 401 refresh it once through
        // the shared session and replay, before treating it as signed out.
        onError: (error, handler) async {
          final req = error.requestOptions;
          if (error.response?.statusCode == 401 && req.extra['retried'] != true) {
            if (await secureStorage.refresh()) {
              final token = await secureStorage.readToken();
              req.extra['retried'] = true;
              req.headers['Authorization'] = 'Bearer $token';
              try {
                return handler.resolve(await dio.fetch(req));
              } on DioException catch (e) {
                return handler.next(e);
              }
            }
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }
}
