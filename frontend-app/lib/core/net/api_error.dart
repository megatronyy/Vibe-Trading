import 'package:dio/dio.dart';

/// Mirrors the React `ApiError` (frontend/src/lib/api.ts). Normalises every
/// backend failure into a single throwable with a stable [status] so the UI
/// can branch on 401/403 ("needs API key") vs anything else.
class ApiException implements Exception {
  ApiException(this.message, {this.status = 0, this.path});

  /// HTTP status, or `0` for transport/non-HTTP failures (timeout, DNS, …).
  final int status;
  final String message;

  /// Request path that failed, for diagnostics.
  final String? path;

  /// True for 401/403 — the caller is missing/has a bad API key.
  bool get isAuthRequired => status == 401 || status == 403;

  factory ApiException.fromDio(DioException e, {String? path}) {
    final response = e.response;
    final code = response?.statusCode ?? 0;
    String detail;
    if (response?.data != null) {
      final data = response!.data;
      if (data is Map && data['detail'] is String) {
        detail = data['detail'] as String;
      } else if (data is String && data.isNotEmpty) {
        detail = data;
      } else {
        detail = e.message ?? _defaultFor(e.type);
      }
    } else {
      detail = e.message ?? _defaultFor(e.type);
    }
    // 401/403 from a reachable backend ⇒ non-loopback access needs an
    // API_AUTH_KEY Bearer token. Surface a clear, actionable message instead
    // of a bare 403.
    if (code == 401 || code == 403) {
      detail = 'Authentication required ($code). Set the backend API key '
          '(API_AUTH_KEY from agent/.env) in Settings → API key.';
    }
    return ApiException(detail, status: code, path: path ?? e.requestOptions.path);
  }

  factory ApiException.transport(String message, {String? path}) =>
      ApiException(message, status: 0, path: path);

  static String _defaultFor(DioExceptionType? t) {
    switch (t) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out';
      case DioExceptionType.connectionError:
        return 'Could not connect to the backend';
      case DioExceptionType.cancel:
        return 'Request cancelled';
      default:
        return 'Network error';
    }
  }

  @override
  String toString() => 'ApiException($status ${path ?? ""}): $message';
}

/// Convenience predicate mirroring React's `isAuthRequiredError`.
bool isAuthRequiredError(Object? error) =>
    error is ApiException && error.isAuthRequired;
