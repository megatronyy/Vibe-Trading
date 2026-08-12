import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'api_error.dart';

/// In-memory cache of the current JWT access token. Set by the auth provider
/// after login/refresh; read by [_BearerInterceptor] so every authenticated
/// request carries it. Kept as a plain top-level mutable (not a provider) to
/// avoid a dependency cycle: the auth notifier reads [apiProvider] →
/// [dioProvider], so dio must not in turn watch the auth provider. The JWT is
/// the source of truth for "who am I" on the wire; [SecureStore] persists it.
String? currentJwt;

/// Builds a fresh [Dio] for the current [AppConfig]. Because [dioProvider]
/// watches [appConfigProvider], changing the base URL in Settings re-creates
/// the client immediately.
final dioProvider = Provider<Dio>((ref) {
  final cfg = ref.watch(appConfigProvider);
  final dio = Dio(BaseOptions(
    baseUrl: cfg.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    responseType: ResponseType.json,
    headers: {'Accept': 'application/json'},
  ));
  dio.interceptors.add(_BearerInterceptor());
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestHeader: false,
      responseHeader: false,
      requestBody: false,
      responseBody: false,
      error: true,
    ));
  }
  ref.onDispose(dio.close);
  return dio;
});

/// Injects the JWT bearer token when present. The backend no longer uses
/// API_AUTH_KEY — all auth is JWT-based via /auth/login.
class _BearerInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final jwt = currentJwt;
    if (jwt != null && jwt.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $jwt';
    }
    handler.next(options);
  }
}

/// Re-exported so call sites can catch [ApiException] without an extra import
/// path mismatch.
typedef ApiExceptionCatcher = ApiException Function(DioException);
