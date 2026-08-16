import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import 'api_error.dart';

/// One decoded SSE frame. `type` is `'message'` when the server omits the
/// `event:` field (matches the WHATWG spec default).
class SseEvent {
  SseEvent({this.id, required this.type, required this.data});

  final String? id;
  final String type;
  final String data;

  /// Decode `data` as JSON, or `null` if it isn't an object.
  Map<String, dynamic>? get json {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  @override
  String toString() => 'SseEvent($type id=${id ?? "-"} len=${data.length})';
}

/// Mobile SSE client: opens `GET <url>` with `ResponseType.stream`, parses the
/// `id/event/data/retry` frame format, dedups by id (LRU-capped), tracks
/// `Last-Event-ID` for resume, and reconnects with exponential backoff.
///
/// This is the direct counterpart of the React `useSSE` hook — minus the
/// browser-only "SSE ticket" detour (mobile carries `Authorization` directly).
class SseClient {
  SseClient({
    required this.dio,
    required this.url,
    this.extraHeaders = const {},
    this.maxSeenIds = 1024,
    this.onAuthError,
  });

  final Dio dio;
  final String url;
  final Map<String, String> extraHeaders;
  final int maxSeenIds;

  /// Invoked when the stream gets a 401/403. Return true to keep the
  /// reconnect loop alive (e.g. the JWT was refreshed and a retry might
  /// succeed); return false or throw to stop permanently. Without a callback
  /// auth errors are terminal.
  final Future<bool> Function()? onAuthError;

  StreamController<SseEvent>? _ctl;
  String? _lastEventId;
  final Set<String> _seen = {};
  int _backoffMs = 1000;
  bool _disposed = false;

  /// Subscribe to the event stream. Closing the returned [StreamSubscription]
  /// (via [dispose]) tears the connection down.
  Stream<SseEvent> connect() {
    _ctl = StreamController<SseEvent>(onCancel: dispose);
    _loop();
    return _ctl!.stream;
  }

  Future<void> _loop() async {
    while (!_disposed && _ctl != null && !_ctl!.isClosed) {
      try {
        await _runOnce();
        _backoffMs = 1000; // clean close → reset
      } on ApiException catch (e) {
        if (e.isAuthRequired) {
          final recovered = await _tryRecoverAuth();
          if (!recovered) {
            // Retrying won't help without new credentials — surface once and
            // stop.
            _ctl?.addError(e);
            break;
          }
          // Token was refreshed — fall through to backoff + retry.
        }
        if (_disposed) break;
      } catch (_) {
        if (_disposed) break;
      }
      if (_disposed) break;
      _backoffMs = min(_backoffMs * 2, 30000);
      await Future.delayed(Duration(milliseconds: _backoffMs));
    }
  }

  Future<bool> _tryRecoverAuth() async {
    final cb = onAuthError;
    if (cb == null) return false;
    try {
      return await cb();
    } catch (_) {
      return false;
    }
  }

  Future<void> _runOnce() async {
    final headers = <String, String>{
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
      ...extraHeaders,
    };
    if (_lastEventId != null) headers['Last-Event-ID'] = _lastEventId!;
    final resp = await dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: headers,
        // SSE streams are long-lived — disable dio's receive timeout so it
        // doesn't kill the connection during quiet periods (heartbeats arrive
        // every ~30s but backtests/swarm can run for minutes without output).
        receiveTimeout: Duration.zero,
        // We inspect the status ourselves so a 401 surfaces cleanly.
        validateStatus: (_) => true,
      ),
    );
    final status = resp.statusCode ?? 0;
    if (status == 401 || status == 403) {
      throw ApiException('SSE auth required', status: status, path: url);
    }
    if (status != 200) {
      throw ApiException.transport('SSE HTTP $status', path: url);
    }
    final stream = resp.data!.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    String? eventType;
    final dataBuf = <String>[];
    String? id;
    await for (final line in stream) {
      if (_disposed) return;
      if (line.isEmpty) {
        if (dataBuf.isNotEmpty) {
          final type =
              (eventType != null && eventType.isNotEmpty) ? eventType : 'message';
          final data = dataBuf.join('\n');
          if (id == null || _seen.add(id)) {
            _ctl?.add(SseEvent(id: id, type: type, data: data));
          }
          if (id != null) {
            _lastEventId = id;
            if (_seen.length > maxSeenIds) {
              _seen.clear();
            }
          }
        }
        eventType = null;
        dataBuf.clear();
        id = null;
        continue;
      }
      if (line.startsWith(':')) continue; // comment / heartbeat prefix
      final colon = line.indexOf(':');
      final field = colon == -1 ? line : line.substring(0, colon);
      var value = colon == -1 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      switch (field) {
        case 'event':
          eventType = value;
          break;
        case 'data':
          dataBuf.add(value);
          break;
        case 'id':
          id = value;
          break;
        case 'retry':
          final ms = int.tryParse(value);
          if (ms != null && ms > 0) _backoffMs = ms;
          break;
      }
    }
  }

  void dispose() {
    _disposed = true;
    _ctl?.close();
  }
}
