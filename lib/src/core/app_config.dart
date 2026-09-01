import '../core/app_state.dart';
import '../core/url_safety.dart';
import '../models/models.dart';

final class OnboardingConfig {
  const OnboardingConfig({
    this.completed = false,
    this.currentStep = 'welcome',
    this.stepIndex = 0,
    this.updatedAt,
  });

  final bool completed;
  final String currentStep;
  final int stepIndex;
  final DateTime? updatedAt;

  OnboardingStep get step =>
      OnboardingStepX.fromPersisted(currentStep, completed: completed);

  Map<String, Object?> toJson() => {
    'completed': completed,
    'current_step': currentStep,
    'step_index': stepIndex,
    'updated_at': updatedAt?.toUtc().toIso8601String(),
  };

  factory OnboardingConfig.fromJson(Map<String, Object?> json) =>
      OnboardingConfig(
        completed: json['completed'] as bool? ?? false,
        currentStep: json['current_step'] as String? ?? 'welcome',
        stepIndex: (json['step_index'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      );

  factory OnboardingConfig.fromStep(OnboardingStep step) => OnboardingConfig(
    completed: step == OnboardingStep.complete,
    currentStep: step.persistedName,
    stepIndex: step.pageIndex,
    updatedAt: DateTime.now().toUtc(),
  );
}

final class AppConfig {
  AppConfig({
    this.version = '1.0.0',
    this.weatherLocations = const [
      WeatherLocation(name: 'Chicago', latitude: 41.8781, longitude: -87.6298),
    ],
    this.stockSymbols = const ['AAPL', 'GOOGL', 'MSFT', 'AMZN', 'NVDA', 'SPY'],
    this.newsKeywords = const ['technology', 'AI', 'markets'],
    List<Bookmark>? browserBookmarks,
    this.supabaseSyncEnabled = true,
    this.onboarding = const OnboardingConfig(),
    this.reminderSettings = const ReminderSettings(),
    this.tasks = const [],
    this.focusMinutes = 25,
  }) : browserBookmarks =
           browserBookmarks ??
           [
             Bookmark(
               id: 'inbox',
               title: 'Inbox',
               url: Uri.https('mail.google.com'),
             ),
             Bookmark(
               id: 'calendar',
               title: 'Calendar',
               url: Uri.https('calendar.google.com'),
             ),
           ];

  final String version;
  final List<WeatherLocation> weatherLocations;
  final List<String> stockSymbols;
  final List<String> newsKeywords;
  final List<Bookmark> browserBookmarks;
  final bool supabaseSyncEnabled;
  final OnboardingConfig onboarding;
  final ReminderSettings reminderSettings;
  final List<DailyTask> tasks;
  final int focusMinutes;

  AppConfig copyWith({
    List<WeatherLocation>? weatherLocations,
    List<String>? stockSymbols,
    List<String>? newsKeywords,
    List<Bookmark>? browserBookmarks,
    bool? supabaseSyncEnabled,
    OnboardingConfig? onboarding,
    ReminderSettings? reminderSettings,
    List<DailyTask>? tasks,
    int? focusMinutes,
  }) => AppConfig(
    version: version,
    weatherLocations: weatherLocations ?? this.weatherLocations,
    stockSymbols: stockSymbols ?? this.stockSymbols,
    newsKeywords: newsKeywords ?? this.newsKeywords,
    browserBookmarks: browserBookmarks ?? this.browserBookmarks,
    supabaseSyncEnabled: supabaseSyncEnabled ?? this.supabaseSyncEnabled,
    onboarding: onboarding ?? this.onboarding,
    reminderSettings: reminderSettings ?? this.reminderSettings,
    tasks: tasks ?? this.tasks,
    focusMinutes: focusMinutes ?? this.focusMinutes,
  );

  Map<String, Object?> toJson() => {
    'version': version,
    'weather_locations': weatherLocations
        .map((value) => value.toJson())
        .toList(),
    'stock_symbols': stockSymbols,
    'news_keywords': newsKeywords,
    'browser_bookmarks': browserBookmarks
        .map((value) => value.toJson())
        .toList(),
    'supabase_sync_enabled': supabaseSyncEnabled,
    'onboarding': onboarding.toJson(),
    'reminder_settings': reminderSettings.toJson(),
    'tasks': tasks.map((value) => value.toJson()).toList(),
    'focus_minutes': focusMinutes,
  };

  factory AppConfig.fromJson(Map<String, Object?> json) => AppConfig(
    version: json['version'] as String? ?? '1.0.0',
    weatherLocations: _objects(
      json['weather_locations'],
    ).map(WeatherLocation.fromJson).toList(),
    stockSymbols: (json['stock_symbols'] as List<Object?>? ?? const [])
        .whereType<String>()
        .toList(),
    newsKeywords: (json['news_keywords'] as List<Object?>? ?? const [])
        .whereType<String>()
        .toList(),
    browserBookmarks: _objects(json['browser_bookmarks'])
        .map(Bookmark.fromJson)
        .where((bookmark) => UrlSafety.isSafeHttpUri(bookmark.url))
        .toList(),
    supabaseSyncEnabled: json['supabase_sync_enabled'] as bool? ?? true,
    onboarding: OnboardingConfig.fromJson(_object(json['onboarding'])),
    reminderSettings: ReminderSettings.fromJson(
      _object(json['reminder_settings']),
    ),
    tasks: _objects(json['tasks'])
        .map(DailyTask.fromJson)
        .where((task) => task.title.trim().isNotEmpty)
        .toList(),
    focusMinutes: (json['focus_minutes'] as num?)?.toInt() ?? 25,
  ).sanitized();

  AppConfig sanitized() {
    final locations = weatherLocations
        .where(
          (location) =>
              location.name.trim().isNotEmpty &&
              location.latitude.isFinite &&
              location.longitude.isFinite &&
              location.latitude >= -90 &&
              location.latitude <= 90 &&
              location.longitude >= -180 &&
              location.longitude <= 180,
        )
        .take(5)
        .toList();
    final symbols = stockSymbols
        .map((value) => value.trim().toUpperCase())
        .where((value) => RegExp(r'^[A-Z0-9._=-]{1,24}$').hasMatch(value))
        .take(20)
        .toSet()
        .toList();
    final keywords = newsKeywords
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .take(20)
        .toList();
    final offsets =
        reminderSettings.offsetsMinutes
            .where((value) => value >= 1 && value <= 1440)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return copyWith(
      weatherLocations: locations,
      stockSymbols: symbols,
      newsKeywords: keywords,
      browserBookmarks: browserBookmarks
          .where((bookmark) => UrlSafety.isSafeHttpUri(bookmark.url))
          .take(50)
          .toList(),
      reminderSettings: reminderSettings.copyWith(
        offsetsMinutes: offsets.take(5).toList(),
      ),
      tasks: tasks.take(100).toList(),
      focusMinutes: focusMinutes.clamp(5, 120),
    );
  }
}

Map<String, Object?> _object(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : {};

Iterable<Map<String, Object?>> _objects(Object? value) =>
    (value is List ? value : const <Object>[]).map(_object);
