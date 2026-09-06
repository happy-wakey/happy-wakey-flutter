import '../models/models.dart';
import 'api_client.dart';

const _maxInboxItems = 20;

/// Read-only inbox adapter used by the morning brief.
///
/// Google and Microsoft tokens are supplied by the existing OAuth session and
/// are never persisted in [AppConfig]. The adapter deliberately fetches a
/// small, recent window and bounds every field before it reaches the UI.
final class InboxService {
  InboxService(this._api);

  final ApiClient _api;

  Future<List<InboxItem>> fetch({
    required String provider,
    required String providerToken,
  }) async {
    if (providerToken.trim().isEmpty) {
      throw const ApiException('Inbox access was not granted at sign-in');
    }
    return switch (provider) {
      'google' => _google(providerToken),
      'azure' || 'microsoft' => _microsoft(providerToken),
      'apple' => throw const ApiException(
        'Apple Sign In supplies identity but not mail access',
      ),
      _ => throw ApiException("Inbox sync isn't supported for '$provider'"),
    };
  }

  Future<List<InboxItem>> _google(String token) async {
    final value = await _api.getJson(
      Uri.https('gmail.googleapis.com', '/gmail/v1/users/me/messages', {
        'q': 'is:unread newer_than:7d -category:promotions -category:social',
        'maxResults': '$_maxInboxItems',
      }),
      headers: {'Authorization': 'Bearer $token'},
      service: 'Gmail inbox',
    );
    final rows = value is Map && value['messages'] is List
        ? (value['messages'] as List).whereType<Map>()
        : const <Map>[];
    final items = <InboxItem>[];
    for (final row in rows.take(_maxInboxItems)) {
      final id = row['id']?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      try {
        final detail = await _api.getJson(
          Uri.https('gmail.googleapis.com', '/gmail/v1/users/me/messages/$id', {
            'format': 'full',
          }),
          headers: {'Authorization': 'Bearer $token'},
          service: 'Gmail message',
        );
        final item = _gmailItem(detail, id);
        if (item != null) items.add(item);
      } on ApiException {
        // One malformed or revoked message must not hide the rest of the
        // inbox; the summary remains a partial-success result.
      }
    }
    return _sorted(items);
  }

  Future<List<InboxItem>> _microsoft(String token) async {
    final value = await _api.getJson(
      Uri.https('graph.microsoft.com', '/v1.0/me/mailFolders/inbox/messages', {
        r'$top': '$_maxInboxItems',
        r'$select':
            'id,subject,from,receivedDateTime,bodyPreview,isRead,importance,webLink',
        r'$orderby': 'receivedDateTime desc',
      }),
      headers: {
        'Authorization': 'Bearer $token',
        'Prefer': 'outlook.body-content-type="text"',
      },
      service: 'Microsoft inbox',
    );
    final rows = value is Map && value['value'] is List
        ? (value['value'] as List).whereType<Map>()
        : const <Map>[];
    return _sorted(
      rows.take(_maxInboxItems).map(_microsoftItem).whereType<InboxItem>(),
    );
  }
}

InboxItem? _gmailItem(Object? raw, String id) {
  if (raw is! Map) return null;
  final payload = raw['payload'] is Map ? raw['payload'] as Map : const {};
  final headers = payload['headers'] is List
      ? (payload['headers'] as List).whereType<Map>()
      : const <Map>[];
  String header(String name) => headers
      .where(
        (value) =>
            value['name']?.toString().toLowerCase() == name.toLowerCase(),
      )
      .map((value) => value['value']?.toString() ?? '')
      .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
  final from = _parseAddress(header('from'));
  final received =
      DateTime.tryParse(header('date')) ??
      DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(raw['internalDate']?.toString() ?? '') ?? 0,
        isUtc: true,
      );
  if (received.millisecondsSinceEpoch == 0) return null;
  final labels = raw['labelIds'] is List
      ? (raw['labelIds'] as List).map((value) => value.toString()).toSet()
      : const <String>{};
  return InboxItem(
    id: id,
    source: 'gmail',
    senderName: _bounded(from.$1, 96),
    senderAddress: _bounded(from.$2, 160),
    subject: _bounded(header('subject'), 180),
    preview: _bounded(raw['snippet'], 320),
    receivedAt: received.toLocal(),
    unread: labels.contains('UNREAD'),
    important: labels.contains('IMPORTANT'),
    // Gmail's message deep link is a fragment; query parameters here would
    // open the compose flow instead of the selected message.
    url: Uri.https(
      'mail.google.com',
      '/mail/u/0/',
    ).replace(fragment: 'inbox/$id'),
  );
}

InboxItem? _microsoftItem(Map raw) {
  final id = _bounded(raw['id'], 180);
  final received = DateTime.tryParse(raw['receivedDateTime']?.toString() ?? '');
  if (id.isEmpty || received == null) return null;
  final from = raw['from'] is Map && (raw['from'] as Map)['emailAddress'] is Map
      ? (raw['from'] as Map)['emailAddress'] as Map
      : const {};
  final importance = raw['importance']?.toString().toLowerCase();
  return InboxItem(
    id: id,
    source: 'outlook',
    senderName: _bounded(from['name'], 96),
    senderAddress: _bounded(from['address'], 160),
    subject: _bounded(raw['subject'], 180),
    preview: _bounded(raw['bodyPreview'], 320),
    receivedAt: received.toLocal(),
    unread: raw['isRead'] != true,
    important: importance == 'high',
    url: _safeUri(raw['webLink']),
  );
}

List<InboxItem> _sorted(Iterable<InboxItem> values) {
  final seen = <String>{};
  final items =
      values
          .where(
            (item) =>
                item.id.isNotEmpty && seen.add('${item.source}|${item.id}'),
          )
          .toList()
        ..sort((left, right) {
          final priority = right.priority.compareTo(left.priority);
          return priority == 0
              ? right.receivedAt.compareTo(left.receivedAt)
              : priority;
        });
  return items.take(_maxInboxItems).toList(growable: false);
}

(String, String) _parseAddress(String raw) {
  final value = _bounded(raw, 220);
  final match = RegExp(r'^\s*(.*?)\s*<([^<>]+)>\s*$').firstMatch(value);
  if (match == null) return (value, value);
  final name = match.group(1)?.replaceAll('"', '').trim() ?? '';
  return (name.isEmpty ? match.group(2) ?? '' : name, match.group(2) ?? '');
}

String _bounded(Object? raw, int max) {
  final value =
      raw?.toString().replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim() ?? '';
  return value.length <= max ? value : '${value.substring(0, max)}…';
}

Uri? _safeUri(Object? raw) {
  final uri = Uri.tryParse(raw?.toString() ?? '');
  return uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty
      ? uri
      : null;
}
