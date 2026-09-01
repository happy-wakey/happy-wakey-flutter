import '../models/models.dart';
import 'api_client.dart';

final class CalendarService {
  CalendarService(this._api);
  final ApiClient _api;

  Future<List<CalendarEvent>> fetch({
    required String provider,
    required String providerToken,
  }) async {
    if (providerToken.trim().isEmpty) {
      throw const ApiException('Calendar access was not granted at sign-in');
    }
    final bounds = _localWeekBounds();
    return switch (provider) {
      'google' => _google(providerToken, bounds.$1, bounds.$2),
      'azure' || 'microsoft' => _microsoft(providerToken, bounds.$1, bounds.$2),
      'apple' => throw const ApiException(
        'Apple Sign In supplies identity but not Apple Calendar access',
      ),
      _ => throw ApiException("Calendar sync isn't supported for '$provider'"),
    };
  }

  Future<List<CalendarEvent>> _google(
    String token,
    DateTime start,
    DateTime end,
  ) async {
    final value = await _api.getJson(
      Uri.https('www.googleapis.com', '/calendar/v3/calendars/primary/events', {
        'timeMin': start.toUtc().toIso8601String(),
        'timeMax': end.toUtc().toIso8601String(),
        'singleEvents': 'true',
        'showDeleted': 'false',
        'conferenceDataVersion': '1',
        'maxResults': '2500',
        'orderBy': 'startTime',
      }),
      headers: {'Authorization': 'Bearer $token'},
      service: 'Google Calendar',
    );
    final items = value is Map && value['items'] is List
        ? value['items'] as List
        : const [];
    return _normalize(items.map(_googleEvent).whereType<CalendarEvent>());
  }

  Future<List<CalendarEvent>> _microsoft(
    String token,
    DateTime start,
    DateTime end,
  ) async {
    final value = await _api.getJson(
      Uri.https('graph.microsoft.com', '/v1.0/me/calendarview', {
        'startDateTime': start.toUtc().toIso8601String(),
        'endDateTime': end.toUtc().toIso8601String(),
        r'$top': '1000',
        r'$select': 'id,iCalUId,subject,bodyPreview,location,start,end,isAllDay,isCancelled,onlineMeeting,onlineMeetingUrl,webLink',
      }),
      headers: {
        'Authorization': 'Bearer $token',
        'Prefer': 'outlook.timezone="UTC"',
      },
      service: 'Microsoft Calendar',
    );
    final items = value is Map && value['value'] is List
        ? value['value'] as List
        : const [];
    return _normalize(items.map(_microsoftEvent).whereType<CalendarEvent>());
  }

  static CalendarAgenda agenda(List<CalendarEvent> events, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final today =
        events
            .where(
              (event) =>
                  !event.isCancelled &&
                  event.start.year == current.year &&
                  event.start.month == current.month &&
                  event.start.day == current.day,
            )
            .toList()
          ..sort((left, right) => left.start.compareTo(right.start));
    final remaining = today
        .where((event) => event.end.isAfter(current))
        .toList();
    final timed = today.where((event) => !event.allDay).toList();
    var conflicts = 0;
    for (var index = 0; index < timed.length; index += 1) {
      if (index > 0 && timed[index].start.isBefore(timed[index - 1].end)) {
        conflicts += 1;
      }
    }
    return CalendarAgenda(
      totalEvents: today.length,
      remainingEvents: remaining.length,
      meetingMinutes: timed.fold(
        0,
        (sum, event) => sum + event.end.difference(event.start).inMinutes,
      ),
      conflictCount: conflicts,
      nextEvent:
          remaining.where((event) => !event.allDay).firstOrNull ??
          remaining.firstOrNull,
    );
  }
}

CalendarEvent? _googleEvent(Object? raw) {
  if (raw is! Map) return null;
  final startMap = raw['start'] is Map ? raw['start'] as Map : const {};
  final endMap = raw['end'] is Map ? raw['end'] as Map : const {};
  final allDay = startMap['dateTime'] == null;
  final start = DateTime.tryParse(
    (startMap[allDay ? 'date' : 'dateTime'])?.toString() ?? '',
  );
  final end = DateTime.tryParse(
    (endMap[allDay ? 'date' : 'dateTime'])?.toString() ?? '',
  );
  if (start == null || end == null || !end.isAfter(start)) return null;
  Uri? joinUrl = _safeUri(raw['hangoutLink']);
  if (joinUrl == null && raw['conferenceData'] is Map) {
    final points = (raw['conferenceData'] as Map)['entryPoints'];
    if (points is List) {
      for (final point in points.whereType<Map>()) {
        if (point['entryPointType'] == 'video') {
          joinUrl = _safeUri(point['uri']);
          if (joinUrl != null) break;
        }
      }
    }
  }
  return CalendarEvent(
    id: raw['id']?.toString() ?? '',
    title: raw['summary']?.toString().trim().isNotEmpty == true
        ? raw['summary'].toString().trim()
        : 'Untitled event',
    start: start.toLocal(),
    end: end.toLocal(),
    allDay: allDay,
    provider: 'google',
    status: raw['status']?.toString() ?? 'confirmed',
    location: raw['location']?.toString(),
    description: raw['description']?.toString(),
    joinUrl: joinUrl,
    eventUrl: _safeUri(raw['htmlLink']),
  );
}

CalendarEvent? _microsoftEvent(Object? raw) {
  if (raw is! Map) return null;
  final startRaw = raw['start'] is Map
      ? (raw['start'] as Map)['dateTime']
      : null;
  final endRaw = raw['end'] is Map ? (raw['end'] as Map)['dateTime'] : null;
  final start = _outlookDate(startRaw);
  final end = _outlookDate(endRaw);
  if (start == null || end == null || !end.isAfter(start)) return null;
  final online = raw['onlineMeeting'] is Map
      ? raw['onlineMeeting'] as Map
      : const {};
  final location = raw['location'] is Map
      ? (raw['location'] as Map)['displayName']
      : null;
  return CalendarEvent(
    id: raw['id']?.toString() ?? '',
    title: raw['subject']?.toString().trim().isNotEmpty == true
        ? raw['subject'].toString().trim()
        : 'Untitled event',
    start: start.toLocal(),
    end: end.toLocal(),
    allDay: raw['isAllDay'] == true,
    provider: 'outlook',
    status: raw['isCancelled'] == true ? 'cancelled' : 'confirmed',
    location: location?.toString(),
    description: raw['bodyPreview']?.toString(),
    joinUrl: _safeUri(online['joinUrl']) ?? _safeUri(raw['onlineMeetingUrl']),
    eventUrl: _safeUri(raw['webLink']),
  );
}

DateTime? _outlookDate(Object? raw) {
  final value = raw?.toString() ?? '';
  return DateTime.tryParse(
    value.endsWith('Z') || value.contains(RegExp(r'[+-]\d\d:\d\d$'))
        ? value
        : '${value}Z',
  );
}

Uri? _safeUri(Object? raw) {
  final value = Uri.tryParse(raw?.toString() ?? '');
  return value != null &&
          (value.scheme == 'https' || value.scheme == 'http') &&
          value.host.isNotEmpty
      ? value
      : null;
}

List<CalendarEvent> _normalize(Iterable<CalendarEvent> input) {
  final seen = <String>{};
  final result =
      input
          .where(
            (event) =>
                event.id.isNotEmpty &&
                seen.add(
                  '${event.provider}|${event.id}|${event.start.toUtc()}',
                ),
          )
          .toList()
        ..sort((left, right) => left.start.compareTo(right.start));
  return result;
}

(DateTime, DateTime) _localWeekBounds() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(
    Duration(days: today.weekday - DateTime.monday),
  );
  return (monday, monday.add(const Duration(days: 7)));
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
