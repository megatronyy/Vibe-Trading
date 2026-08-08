import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/api.dart';
import '../net/api_client.dart';
import '../net/api_error.dart';
import '../storage/secure_store.dart';

/// Auth view-state. `isAnonymous` is true only during the initial load from
/// secure storage (primed in `main` before the first frame) — the router
/// redirect treats it as "decision pending" so a logged-in user is never
/// bounced to /login on cold start, and a logged-out user doesn't flash /agent.
class AuthState {
  const AuthState({
    this.userId,
    this.userName,
    this.role,
    this.jwt,
    this.jwtExp,
    this.isLoggedIn = false,
    this.isAnonymous = true,
  });

  final String? userId;
  final String? userName;
  final String? role;
  final String? jwt;
  final String? jwtExp; // ISO-8601 expiry from /auth/login `expires_at`
  final bool isLoggedIn;
  final bool isAnonymous;

  AuthState copyWith({
    String? userId,
    String? userName,
    String? role,
    String? jwt,
    String? jwtExp,
    bool? isLoggedIn,
    bool? isAnonymous,
    bool clearJwt = false,
  }) =>
      AuthState(
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        role: role ?? this.role,
        jwt: clearJwt ? null : (jwt ?? this.jwt),
        jwtExp: clearJwt ? null : (jwtExp ?? this.jwtExp),
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        isAnonymous: isAnonymous ?? this.isAnonymous,
      );
}

/// Outcome of a login/register attempt. The page surfaces [error] (if any) in
/// a SnackBar; on success the router redirect moves the user off /login.
class AuthResult {
  const AuthResult({required this.success, this.error});
  final bool success;
  final String? error;
}

/// Owns authentication: loads the persisted JWT/user at startup, exposes
/// login/register/logout, and refreshes an expired JWT. The in-memory
/// [currentJwt] holder is kept in sync so the dio interceptor injects the
/// token on every authenticated request.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Api get _api => ref.read(apiProvider);

  /// Read persisted credentials into state. Called once from `main` before the
  /// UI boots so the first frame already knows the auth status.
  Future<void> load() async {
    final jwt = await secureStore.getJwt();
    final exp = await secureStore.getJwtExp();
    final uid = await secureStore.getUserId();
    final name = await secureStore.getUserName();
    currentJwt = jwt;
    state = AuthState(
      userId: uid,
      userName: name,
      jwt: jwt,
      jwtExp: exp,
      isLoggedIn: jwt != null && jwt.isNotEmpty,
      isAnonymous: false,
    );
  }

  /// POST /auth/login. On success stores JWT + user, returns success. On
  /// failure returns the backend error message for the UI to display.
  Future<AuthResult> login(String username, String password) =>
      _doAuth(() => _api.login(username, password));

  /// POST /auth/register. Same response shape as login.
  Future<AuthResult> register(String username, String password) =>
      _doAuth(() => _api.register(username, password));

  Future<AuthResult> _doAuth(
      Future<Map<String, dynamic>> Function() call) async {
    try {
      final r = await call();
      await _applyAuthResponse(r);
      return const AuthResult(success: true);
    } on ApiException catch (e) {
      return AuthResult(success: false, error: e.message);
    } catch (e) {
      return AuthResult(success: false, error: e.toString());
    }
  }

  /// Persist a /auth/login | /auth/refresh response and flip to logged-in.
  Future<void> _applyAuthResponse(Map<String, dynamic> r) async {
    final jwt = r['jwt'] as String?;
    final exp = r['expires_at'] as String?;
    final user = (r['user'] as Map?)?.cast<String, dynamic>();
    final uid = user?['user_id']?.toString();
    final name = user?['username'] as String?;
    final role = user?['role'] as String?;
    currentJwt = jwt;
    await secureStore.setJwt(jwt);
    await secureStore.setJwtExp(exp);
    await secureStore.setUserId(uid);
    await secureStore.setUserName(name);
    state = AuthState(
      userId: uid,
      userName: name,
      role: role,
      jwt: jwt,
      jwtExp: exp,
      isLoggedIn: jwt != null && jwt.isNotEmpty,
      isAnonymous: false,
    );
  }

  /// Clear all stored credentials and flip to logged-out. Connection / theme /
  /// locale settings survive (those are app preferences, not identity).
  Future<void> logout() async {
    currentJwt = null;
    await secureStore.clearAuth();
    state = const AuthState(isLoggedIn: false, isAnonymous: false);
  }

  /// If the JWT has expired (or we can't tell), try POST /auth/refresh. On
  /// failure (e.g. refresh token also expired) we log out — the redirect then
  /// sends the user back to /login. No-op when not logged in.
  Future<void> checkAndRefresh() async {
    final s = state;
    if (!s.isLoggedIn) return;
    final exp = s.jwtExp;
    final expired = exp == null || _isExpired(exp);
    if (!expired) return;
    try {
      final r = await _api.refreshAuth();
      await _applyAuthResponse(r);
    } catch (_) {
      await logout();
    }
  }

  bool _isExpired(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return false; // unparseable ⇒ assume still valid
    return dt.isBefore(DateTime.now());
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
