import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alpha.dart';
import '../models/correlation.dart';
import '../models/goal.dart';
import '../models/models.dart';
import '../models/run.dart';
import 'api_client.dart';
import 'api_error.dart';

/// REST client — 1:1 with `frontend/src/lib/api.ts`. P0 ships the session /
/// health surface needed to validate the connection; the remaining methods
/// (runs, swarm, alpha, correlation, live, settings, channels, upload) are
/// added in their phases (P2–P4) but the helper plumbing lives here now.
class Api {
  Api(this._dio);

  final Dio _dio;

  // --- health ---
  Future<HealthStatus> getHealth() async =>
      HealthStatus.fromJson(await _object('/health'));

  // --- auth (P1) ---
  /// POST /auth/login → {jwt, expires_at, user:{user_id, username, role}}.
  Future<Map<String, dynamic>> login(String username, String password) async =>
      _post('/auth/login', {'username': username, 'password': password});

  /// POST /auth/register → same response shape as [login].
  Future<Map<String, dynamic>> register(
          String username, String password) async =>
      _post('/auth/register', {'username': username, 'password': password});

  /// GET /auth/me → {user_id, username, role}.
  Future<Map<String, dynamic>> authMe() async => _object('/auth/me');

  /// POST /auth/refresh → same response shape as [login]. Requires a valid
  /// (non-expired) JWT in the Authorization header, injected by the dio
  /// interceptor from the in-memory `currentJwt` holder.
  Future<Map<String, dynamic>> refreshAuth() async => _post('/auth/refresh', {});

  // --- sessions / messages ---
  Future<List<SessionItem>> listSessions() async =>
      (await _data('/sessions') as List)
          .cast<Map<String, dynamic>>()
          .map(SessionItem.fromJson)
          .toList();

  Future<SessionItem> createSession([String? title]) async =>
      SessionItem.fromJson(await _post('/sessions', {'title': title ?? ''}));

  Future<void> deleteSession(String id) async => _dio.delete('/sessions/$id');

  Future<SessionItem> renameSession(String id, String title) async =>
      SessionItem.fromJson(await _patch('/sessions/$id', {'title': title}));

  Future<List<MessageItem>> getSessionMessages(String id) async =>
      (await _data('/sessions/$id/messages') as List)
          .cast<Map<String, dynamic>>()
          .map(MessageItem.fromJson)
          .toList();

  Future<Map<String, dynamic>> sendMessage(String id, String content) =>
      _post('/sessions/$id/messages', {'content': content});

  Future<void> cancelSession(String id) async =>
      _dio.post('/sessions/$id/cancel');

  /// SSE events URL for a session. `replayActive` mirrors `api.sseUrl({replay})`.
  String sessionEventsUrl(String id, {bool replayActive = false}) {
    final base = '/sessions/$id/events';
    return replayActive ? '$base?replay=active' : base;
  }

  // --- runs / backtests ---
  Future<List<RunListItem>> listRuns([int? limit]) async {
    final path = limit != null ? '/runs?limit=${Uri.encodeQueryComponent(limit.toString())}' : '/runs';
    return ((await _data(path)) as List)
        .cast<Map<String, dynamic>>()
        .map(RunListItem.fromJson)
        .toList();
  }

  Future<RunData> getRun(String id,
      {String? chartPayload, String? chartSymbol}) async {
    final q = <String, dynamic>{};
    if (chartPayload != null) q['chart_payload'] = chartPayload;
    if (chartSymbol != null) q['chart_symbol'] = chartSymbol;
    final j = await _data('/runs/$id', query: q.isEmpty ? null : q);
    return RunData.fromJson(j as Map<String, dynamic>);
  }

  Future<Map<String, String>> getRunCode(String id) async {
    final j = await _data('/runs/$id/code');
    return (j as Map).cast<String, String>();
  }

  Future<bool> runHasPine(String id) async {
    try {
      final j = await _data('/runs/$id/pine') as Map;
      return j['exists'] == true;
    } on ApiException {
      return false;
    }
  }

  Future<String?> getRunPine(String id) async {
    final j = await _data('/runs/$id/pine') as Map;
    return j['content'] as String?;
  }

  // --- alpha zoo ---
  Future<List<AlphaSummary>> listAlphas(
      {String? zoo, String? theme, String? universe, int? limit}) async {
    final q = <String, dynamic>{};
    if (zoo != null) q['zoo'] = zoo;
    if (theme != null) q['theme'] = theme;
    if (universe != null) q['universe'] = universe;
    if (limit != null) q['limit'] = limit;
    final j = await _data('/alpha/list', query: q.isEmpty ? null : q);
    final list = j is List
        ? j
        : ((j is Map ? j['alphas'] : null) as List?) ?? const [];
    return list.cast<Map<String, dynamic>>().map(AlphaSummary.fromJson).toList();
  }

  Future<AlphaDetail> getAlpha(String id) async =>
      AlphaDetail.fromJson(await _object('/alpha/$id'));

  Future<String> createAlphaBench(Map<String, dynamic> body) async =>
      ((await _post('/alpha/bench', body))['job_id'] ?? '') as String;

  String alphaBenchStreamUrl(String jobId) => '/alpha/bench/$jobId/stream';

  Future<String> createAlphaCompare(Map<String, dynamic> body) async =>
      ((await _post('/alpha/compare', body))['job_id'] ?? '') as String;

  String alphaCompareStreamUrl(String jobId) => '/alpha/compare/$jobId/stream';

  // --- correlation ---
  Future<CorrelationResponse> getCorrelation(
      String codes, int days, String method) async {
    final q = 'codes=${Uri.encodeQueryComponent(codes)}'
        '&days=$days&method=$method';
    return CorrelationResponse.fromJson(await _object('/correlation?$q'));
  }

  Future<CorrelationRegimeResponse> getCorrelationRegime(
      String codes, int days) async {
    final q = 'codes=${Uri.encodeQueryComponent(codes)}&days=$days';
    return CorrelationRegimeResponse.fromJson(
        await _object('/correlation/regime?$q'));
  }

  // --- goal lifecycle (research goal) ---
  Future<GoalSnapshot> getGoal(String sid) async =>
      GoalSnapshot.fromJson(await _object('/sessions/$sid/goal'));

  Future<GoalSnapshot> createGoal(String sid, Map<String, dynamic> body) async =>
      GoalSnapshot.fromJson(await _post('/sessions/$sid/goal', body));

  Future<GoalSnapshot> updateGoal(
          String sid, Map<String, dynamic> body) async =>
      GoalSnapshot.fromJson(await _patch('/sessions/$sid/goal', body));

  Future<void> updateGoalStatus(String sid, String status) async =>
      _patch('/sessions/$sid/goal/status', {'status': status});

  // --- live / safety (privileged surface) ---
  Future<LiveStatus> getLiveStatus() async =>
      LiveStatus.fromJson(await _object('/live/status'));

  /// Global kill switch. Always callable — halt is global even with no session.
  Future<Map<String, dynamic>> haltLive(
      {String? sessionId, String? broker, String? reason}) async {
    final body = <String, dynamic>{};
    if (sessionId != null) body['session_id'] = sessionId;
    if (broker != null) body['broker'] = broker;
    if (reason != null) body['reason'] = reason;
    return _post('/live/halt', body);
  }

  /// Resume live trading after a halt. Scoped to a broker if provided, else
  /// clears the global halt.
  Future<Map<String, dynamic>> resumeLive(
      {String? sessionId, String? broker}) async {
    final body = <String, dynamic>{};
    if (sessionId != null) body['session_id'] = sessionId;
    if (broker != null) body['broker'] = broker;
    return _post('/live/resume', body);
  }

  Future<Map<String, dynamic>> authorizeLive(String broker) async =>
      _post('/live/authorize', {'broker': broker});

  Future<Map<String, dynamic>> startLiveRunner(String broker) async =>
      _post('/live/runner/start', {'broker': broker});

  Future<Map<String, dynamic>> stopLiveRunner(String broker) async =>
      _post('/live/runner/stop', {'broker': broker});

  Future<Map<String, dynamic>> verifyConnector(String profileId) async =>
      _post('/live/connectors/$profileId/verify', {});

  /// Privileged: commit a mandate profile. Backend requires `consent_ack`
  /// true; the mobile caller gates this behind biometric confirmation.
  Future<Map<String, dynamic>> commitMandate(Map<String, dynamic> body) async =>
      _post('/mandate/commit', body);

  // --- session auto-title ---
  Future<void> autoTitleSession(String sessionId) async {
    try {
      await _dio.post('/sessions/$sessionId/title/auto');
    } catch (_) {}
  }

  // --- settings ---
  Future<Map<String, dynamic>> getLLMSettings() async => _object('/settings/llm');
  Future<Map<String, dynamic>> updateLLMSettings(Map<String, dynamic> body) async =>
      _put('/settings/llm', body);

  /// List available LLM models for a provider (model discovery).
  Future<List<String>> listLLMModels(String provider) async {
    try {
      final r = await _post('/settings/llm/models', {'provider': provider});
      final models = r['models'];
      if (models is List) return models.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  Future<Map<String, dynamic>> getDataSourceSettings() async =>
      _object('/settings/data-sources');
  Future<Map<String, dynamic>> updateDataSourceSettings(Map<String, dynamic> body) async =>
      _put('/settings/data-sources', body);
  Future<Map<String, dynamic>> getChannelStatus() async => _object('/channels/status');
  Future<void> startChannels() async => _dio.post('/channels/start');
  Future<void> stopChannels() async => _dio.post('/channels/stop');

  // --- scheduled research ---
  Future<List<Map<String, dynamic>>> listScheduledRuns() async {
    final j = await _data('/scheduled-runs');
    return (j as List?)?.cast<Map<String, dynamic>>() ?? const [];
  }

  Future<Map<String, dynamic>> createScheduledRun(Map<String, dynamic> body) async =>
      _post('/scheduled-runs', body);

  Future<void> deleteScheduledRun(String jobId) async =>
      _dio.delete('/scheduled-runs/$jobId');

  /// Streaming chunked upload of a broker export / doc → POST /upload.
  Future<Map<String, dynamic>> uploadFile(String filePath, String filename) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
    });
    try {
      final r = await _dio.post('/upload', data: form);
      return r.data is Map ? r.data as Map<String, dynamic> : <String, dynamic>{};
    } on DioException catch (e) {
      throw ApiException.fromDio(e, path: '/upload');
    }
  }

  // --- internal JSON helpers ---------------------------------------------

  Future<dynamic> _data(String path, {Map<String, dynamic>? query}) async {
    try {
      final r = await _dio.get(path, queryParameters: query);
      return r.data;
    } on DioException catch (e) {
      throw ApiException.fromDio(e, path: path);
    }
  }

  Future<Map<String, dynamic>> _object(String path) async =>
      (await _data(path)) as Map<String, dynamic>;

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final r = await _dio.post(path, data: body);
      return r.data is Map ? r.data as Map<String, dynamic> : <String, dynamic>{};
    } on DioException catch (e) {
      throw ApiException.fromDio(e, path: path);
    }
  }

  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) async {
    try {
      final r = await _dio.patch(path, data: body);
      return r.data is Map ? r.data as Map<String, dynamic> : <String, dynamic>{};
    } on DioException catch (e) {
      throw ApiException.fromDio(e, path: path);
    }
  }

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    try {
      final r = await _dio.put(path, data: body);
      return r.data is Map ? r.data as Map<String, dynamic> : <String, dynamic>{};
    } on DioException catch (e) {
      throw ApiException.fromDio(e, path: path);
    }
  }
}

final apiProvider = Provider<Api>((ref) => Api(ref.watch(dioProvider)));
