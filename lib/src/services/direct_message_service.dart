import '../core/environment.dart';
import '../core/url_safety.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Read-only social/work DM adapter.
///
/// Provider tokens are intentionally not collected in the client. A
/// configured Happy Wakey platform gateway can fan in Slack, Discord, Teams,
/// and other approved sources after its own OAuth and consent checks. The
/// client sends only the short-lived Supabase bearer for that request.
final class DirectMessageService {
  DirectMessageService(this._api, {String? baseUrl})
    : _baseUrl =
          (baseUrl ??
                  (Environment.gatewayUrl.isEmpty
                      ? Environment.platformUrl
                      : Environment.gatewayUrl))
              .trim();

  static const _maxItems = 20;
  final ApiClient _api;
  final String _baseUrl;

  bool get configured => _baseUrl.isNotEmpty;

  Future<List<DirectMessage>> fetch({required String accessToken}) async {
    if (accessToken.trim().isEmpty) {
      throw const ApiException('Sign in before reading direct messages');
    }
    if (!configured) {
      throw const ApiException(
        'Direct-message gateway is not configured for this build',
      );
    }
    final base = Uri.tryParse(_baseUrl);
    if (base == null || !UrlSafety.isSafeHttpUri(base)) {
      throw const ApiException('Direct-message gateway URL is not safe');
    }
    final uri = base.resolve('/v1/briefing/direct-messages');
    final value = await _api.getJson(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
      service: 'Direct-message gateway',
    );
    final rows = value is Map && value['items'] is List
        ? (value['items'] as List).whereType<Map>()
        : value is List
        ? value.whereType<Map>()
        : const <Map>[];
    final seen = <String>{};
    final items =
        rows
            .take(_maxItems)
            .map(_parse)
            .whereType<DirectMessage>()
            .where((item) => seen.add('${item.source}|${item.id}'))
            .toList()
          ..sort((left, right) => right.receivedAt.compareTo(left.receivedAt));
    return items.take(_maxItems).toList(growable: false);
  }
}

DirectMessage? _parse(Map raw) {
  final id = _bounded(raw['id'], 180);
  final received = DateTime.tryParse(raw['receivedAt']?.toString() ?? '');
  if (id.isEmpty || received == null) return null;
  final url = Uri.tryParse(raw['url']?.toString() ?? '');
  return DirectMessage(
    id: id,
    source: _bounded(raw['source'], 40),
    conversation: _bounded(raw['conversation'] ?? raw['channel'], 120),
    senderName: _bounded(raw['senderName'] ?? raw['sender'], 96),
    preview: _bounded(raw['preview'] ?? raw['text'], 320),
    receivedAt: received.toLocal(),
    unread: raw['unread'] == true,
    url: url != null && UrlSafety.isSafeHttpUri(url) ? url : null,
  );
}

String _bounded(Object? raw, int max) {
  final value =
      raw?.toString().replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim() ?? '';
  return value.length <= max ? value : '${value.substring(0, max)}…';
}
