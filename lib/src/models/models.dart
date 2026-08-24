import 'package:flutter/foundation.dart';

@immutable
final class WeatherLocation {
  const WeatherLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;

  Map<String, Object> toJson() => {
    'name': name,
    'lat': latitude,
    'lon': longitude,
  };

  factory WeatherLocation.fromJson(Map<String, Object?> json) =>
      WeatherLocation(
        name: json['name'] as String? ?? '',
        latitude: (json['lat'] as num?)?.toDouble() ?? 0,
        longitude: (json['lon'] as num?)?.toDouble() ?? 0,
      );
}

@immutable
final class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.weatherCode,
    required this.condition,
    required this.high,
    required this.low,
    required this.precipitationProbability,
  });

  final DateTime date;
  final int weatherCode;
  final String condition;
  final double high;
  final double low;
  final double precipitationProbability;
}

@immutable
final class WeatherData {
  const WeatherData({
    required this.locationName,
    required this.temperature,
    required this.feelsLike,
    required this.condition,
    required this.weatherCode,
    required this.humidity,
    required this.windSpeed,
    required this.precipitation,
    required this.isDay,
    required this.observedAt,
    required this.forecast,
  });

  final String locationName;
  final double temperature;
  final double feelsLike;
  final String condition;
  final int weatherCode;
  final double humidity;
  final double windSpeed;
  final double precipitation;
  final bool isDay;
  final DateTime observedAt;
  final List<DailyForecast> forecast;
}

@immutable
final class StockQuote {
  const StockQuote({
    required this.symbol,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.high,
    required this.low,
  });

  final String symbol;
  final double price;
  final double change;
  final double changePercent;
  final double high;
  final double low;
}

@immutable
final class NewsItem {
  const NewsItem({
    required this.title,
    required this.source,
    required this.url,
    required this.publishedAt,
    this.description,
    this.imageUrl,
  });

  final String title;
  final String source;
  final Uri url;
  final DateTime? publishedAt;
  final String? description;
  final Uri? imageUrl;
}

@immutable
final class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.provider,
    required this.status,
    this.location,
    this.joinUrl,
    this.eventUrl,
    this.description,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String provider;
  final String status;
  final String? location;
  final Uri? joinUrl;
  final Uri? eventUrl;
  final String? description;

  bool get isCancelled => status == 'cancelled';
}

@immutable
final class CalendarAgenda {
  const CalendarAgenda({
    required this.totalEvents,
    required this.remainingEvents,
    required this.meetingMinutes,
    required this.conflictCount,
    this.nextEvent,
  });

  const CalendarAgenda.empty()
    : totalEvents = 0,
      remainingEvents = 0,
      meetingMinutes = 0,
      conflictCount = 0,
      nextEvent = null;

  final int totalEvents;
  final int remainingEvents;
  final int meetingMinutes;
  final int conflictCount;
  final CalendarEvent? nextEvent;
}

@immutable
final class Bookmark {
  const Bookmark({required this.id, required this.title, required this.url});

  final String id;
  final String title;
  final Uri url;

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'url': url.toString(),
  };

  factory Bookmark.fromJson(Map<String, Object?> json) => Bookmark(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    url: Uri.tryParse(json['url'] as String? ?? '') ?? Uri(),
  );
}

@immutable
final class ReminderSettings {
  const ReminderSettings({
    this.enabled = true,
    this.cloudEmailEnabled = false,
    this.offsetsMinutes = const [30, 10],
  });

  final bool enabled;
  final bool cloudEmailEnabled;
  final List<int> offsetsMinutes;

  ReminderSettings copyWith({
    bool? enabled,
    bool? cloudEmailEnabled,
    List<int>? offsetsMinutes,
  }) => ReminderSettings(
    enabled: enabled ?? this.enabled,
    cloudEmailEnabled: cloudEmailEnabled ?? this.cloudEmailEnabled,
    offsetsMinutes: offsetsMinutes ?? this.offsetsMinutes,
  );

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'cloud_email_enabled': cloudEmailEnabled,
    'offsets_minutes': offsetsMinutes,
  };

  factory ReminderSettings.fromJson(Map<String, Object?> json) =>
      ReminderSettings(
        enabled: json['enabled'] as bool? ?? true,
        cloudEmailEnabled: json['cloud_email_enabled'] as bool? ?? false,
        offsetsMinutes:
            (json['offsets_minutes'] as List<Object?>? ?? const [30, 10])
                .whereType<num>()
                .map((value) => value.toInt())
                .toList(),
      );
}

@immutable
final class DailyTask {
  const DailyTask({
    required this.id,
    required this.title,
    this.completed = false,
  });

  final String id;
  final String title;
  final bool completed;

  DailyTask copyWith({String? title, bool? completed}) => DailyTask(
    id: id,
    title: title ?? this.title,
    completed: completed ?? this.completed,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'completed': completed,
  };

  factory DailyTask.fromJson(Map<String, Object?> json) => DailyTask(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    completed: json['completed'] as bool? ?? false,
  );
}
