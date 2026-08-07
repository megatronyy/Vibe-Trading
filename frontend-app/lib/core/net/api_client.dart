import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'api_error.dart';

/// Builds a fresh [Dio] for the current [AppConfig]. Because [dioProvider]
/// watches [appConfigProvider], changing the base URL or API key in Settings
/// re-creates the client immediately — no restart/reload needed (this replaces
/// the React app's `window.location.reload()` after saving the API key).
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
  dio.interceptors.add(_BearerInterceptor(cfg.apiKey));
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

/// Injects the bearer token when present. Mobile SSE can carry this header
/// directly, so the React frontend's "SSE ticket" detour is unnecessary here.
class _BearerInterceptor extends Interceptor {
  _BearerInterceptor(this._apiKey);
  final String _apiKey;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_apiKey.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $_apiKey';
    }
    handler.next(options);
  }
}

/// Re-exported so call sites can catch [ApiException] without an extra import
/// path mismatch.
typedef ApiExceptionCatcher = ApiException Function(DioException);
