import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../core/environment.dart';
import '../models/models.dart';
import 'api_client.dart';

final class CloudReminderResult {
  const CloudReminderResult({
    required this.accepted,
    required this.unchanged,
    required this.pending,
  });
  final int accepted;
  final int unchanged;
  final int pending;
}

final class CloudReminderService {
  CloudReminderService(this._api);
  final ApiClient _api;

  String? _sharedToken;
  int _sharedTokenExpiresAt = 0;
  String? _sourceFingerprint;

  void clearSession() {
    _sharedToken = null;
    _sharedTokenExpiresAt = 0;
    _sourceFingerprint = null;
  }

  Future<CloudReminderResult> sync({
    required String supabaseAccessToken,
    required List<CalendarEvent> events,
    required ReminderSettings settings,
  }) async {
    if (!settings.cloudEmailEnabled) {
      return const CloudReminderResult(accepted: 0, unchanged: 0, pending: 0);
    }
    final token = await _sharedAuthToken(supabaseAccessToken);
    final now = DateTime.now();
    final jobs = <Map<String, Object>>[];
    for (final event in events) {
      if (event.allDay || event.isCancelled || !event.start.isAfter(now)) {
        continue;
      }
      for (final offset in settings.offsetsMinutes) {
        final trigger = event.start.subtract(Duration(minutes: offset));
        if (trigger.isBefore(now)) continue;
        final key = sha256
            .convert(
              utf8.encode(
                'v1|${event.provider}|${event.id}|${event.start.toUtc()}|$offset',
              ),
            )
            .toString();
        jobs.add({
          'job_id': key,
          'idempotency_key': key,
          'title': event.title,
          'body':
              'Starts in $offset minute${offset == 1 ? '' : 's'}${event.location == null ? '' : '\n${event.location}'}',
          'trigger_at': trigger.toUtc().millisecondsSinceEpoch ~/ 1000,
          'channel': 'email',
        });
      }
    }
    final sync = await _api.putJson(
      _gatewayUri('/v1/reminders/sync'),
      headers: {'Authorization': 'Bearer $token'},
      body: {'jobs': jobs},
      service: 'Happy Wakey cloud reminders',
    );
    final status = await _api.getJson(
      _gatewayUri('/v1/reminders/status'),
      headers: {'Authorization': 'Bearer $token'},
      service: 'Happy Wakey cloud reminder status',
    );
    final syncResult = sync is Map && sync['result'] is Map
        ? sync['result'] as Map
        : const {};
    final reminders = status is Map && status['reminders'] is Map
        ? status['reminders'] as Map
        : const {};
    return CloudReminderResult(
      accepted: (syncResult['accepted'] as num?)?.toInt() ?? 0,
      unchanged: (syncResult['unchanged'] as num?)?.toInt() ?? 0,
      pending: (reminders['pending'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> sendTest(String supabaseAccessToken) async {
    final token = await _sharedAuthToken(supabaseAccessToken);
    await _api.postJson(
      _gatewayUri('/v1/reminders/test'),
      headers: {'Authorization': 'Bearer $token'},
      body: const <String, Object>{},
      service: 'Happy Wakey cloud reminder test',
    );
  }

  Future<String> _sharedAuthToken(String supabaseAccessToken) async {
    if (supabaseAccessToken.isEmpty || supabaseAccessToken.length > 16 * 1024) {
      throw const ApiException('The Supabase session is missing or invalid');
    }
    final fingerprint = sha256
        .convert(utf8.encode(supabaseAccessToken))
        .toString();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    if (_sharedToken != null &&
        _sourceFingerprint == fingerprint &&
        _sharedTokenExpiresAt > now + 60) {
      return _sharedToken!;
    }
    final value = await _api.postJson(
      _sharedAuthUri('/auth/exchange'),
      headers: {'Authorization': 'Bearer $supabaseAccessToken'},
      body: const <String, Object>{},
      service: 'Shared auth',
    );
    if (value is! Map) {
      throw const ApiException('Shared auth returned an invalid session');
    }
    final accessToken = value['access_token']?.toString() ?? '';
    final expiresAt = (value['expires_at'] as num?)?.toInt() ?? 0;
    if (accessToken.isEmpty ||
        accessToken.length > 16 * 1024 ||
        expiresAt <= now + 60) {
      throw const ApiException('Shared auth returned an invalid session');
    }
    _sharedToken = accessToken;
    _sharedTokenExpiresAt = expiresAt;
    _sourceFingerprint = fingerprint;
    return accessToken;
  }

  Uri _sharedAuthUri(String path) => _serviceUri(
    Environment.sharedAuthUrl.isEmpty
        ? Environment.platformUrl
        : Environment.sharedAuthUrl,
    path,
  );

  Uri _gatewayUri(String path) => _serviceUri(
    Environment.gatewayUrl.isEmpty
        ? Environment.platformUrl
        : Environment.gatewayUrl,
    path,
  );

  Uri _serviceUri(String base, String path) {
    final uri = Uri.tryParse(base);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const ApiException('Happy Wakey service URL is invalid');
    }
    return uri.replace(
      path: '${uri.path.replaceFirst(RegExp(r'/$'), '')}$path',
    );
  }
}
