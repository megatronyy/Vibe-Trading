import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'api_error.dart';

/// In-memory cache of the current JWT access token. Set by the auth provider
/// after login/refresh; read by [_AuthInterceptor] so every authenticated
/// request carries it. Kept as a plain top-level mutable (not a provider) to
/// avoid a dependency cycle: the auth notifier reads [apiProvider] →
/// [dioProvider], so dio must not in turn watch the auth provider. The JWT is
/// the source of truth for "who am I" on the wire; [SecureStore] persists it.
String? currentJwt;

/// Hooks registered by the auth notifier (see its `build`). They let the dio
/// interceptor — which cannot read the auth provider without creating the
/// cycle described above — sync auth state after an interceptor-driven
/// `/auth/refresh`, and force a logout when the session is unrecoverable.
/// Both receive the raw auth response shape `{jwt, expires_at, user}`.
void Function(Map<String, dynamic> response)? onJwtRefreshed;
void Function()? onAuthSessionExpired;

/// Auth endpoints that must never trigger the 401→refresh→retry dance (their
/// 401s are the answer, not a recoverable auth state).
const _noRefreshPaths = {'/auth/login', '/auth/register', '/auth/refresh'};

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
  // Bare client for /auth/refresh and request retries — no interceptors, so
  // a 401 during refresh cannot recurse.
  final refreshDio = Dio(BaseOptions(
    baseUrl: cfg.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json'},
  ));
  dio.interceptors.add(_AuthInterceptor(refreshDio));
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestHeader: false,
      responseHeader: false,
      requestBody: false,
      responseBody: false,
      error: true,
    ));
  }
  ref.onDispose(() {
    dio.close();
    refreshDio.close();
  });
  return dio;
});

/// Injects the JWT bearer token when present, and transparently recovers from
/// an auth failure (401/403) on authenticated endpoints: tries a single-flight
/// `POST /auth/refresh`, retries the original request once with the new token,
/// and reports an unrecoverable session via [onAuthSessionExpired] so the app
/// lands on /login instead of erroring on every request.
class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._refreshDio);

  final Dio _refreshDio;
  Future<bool>? _refreshInFlight;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final jwt = currentJwt;
    if (jwt != null && jwt.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $jwt';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;
    final isAuthError = status == 401 || status == 403;
    final alreadyRetried =
        err.requestOptions.extra['__auth_retried'] == true;
    final hadToken = currentJwt != null && currentJwt!.isNotEmpty;
    if (!isAuthError || alreadyRetried || !hadToken ||
        _noRefreshPaths.contains(path)) {
      handler.next(err);
      return;
    }
    final refreshed = await _tryRefresh();
    if (refreshed) {
      try {
        final opts = err.requestOptions;
        opts.extra['__auth_retried'] = true;
        opts.headers['Authorization'] = 'Bearer $currentJwt';
        handler.resolve(await _refreshDio.fetch(opts));
        return;
      } catch (_) {
        // Retry failed too — surface the original error below.
      }
    } else {
      // A present token that even /auth/refresh cannot save ⇒ the session is
      // dead. Log out so the router redirect sends the user to /login.
      onAuthSessionExpired?.call();
    }
    handler.next(err);
  }

  /// Single-flight refresh: concurrent 401s share one /auth/refresh call.
  Future<bool> _tryRefresh() {
    final pending = _refreshInFlight;
    if (pending != null) return pending;
    final future = _doRefresh();
    _refreshInFlight = future;
    return future.whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _doRefresh() async {
    final jwt = currentJwt;
    if (jwt == null || jwt.isEmpty) return false;
    try {
      final r = await _refreshDio.post(
        '/auth/refresh',
        options: Options(headers: {'Authorization': 'Bearer $jwt'}),
      );
      final data = r.data;
      if (r.statusCode == 200 &&
          data is Map &&
          data['jwt'] is String &&
          (data['jwt'] as String).isNotEmpty) {
        currentJwt = data['jwt'] as String;
        final cast = data.cast<String, dynamic>();
        try {
          onJwtRefreshed?.call(cast);
        } catch (_) {}
        return true;
      }
    } catch (_) {}
    return false;
  }
}

/// Re-exported so call sites can catch [ApiException] without an extra import
/// path mismatch.
typedef ApiExceptionCatcher = ApiException Function(DioException);
