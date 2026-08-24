import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

abstract interface class ConfigStore {
  Future<AppConfig> load();
  Future<void> save(AppConfig config);
}

final class SharedPreferencesConfigStore implements ConfigStore {
  static const _key = 'happy_wakey.config.v1';

  @override
  Future<AppConfig> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key);
    if (encoded == null) return AppConfig();
    try {
      final value = jsonDecode(encoded);
      if (value is! Map<String, Object?>) return AppConfig();
      return AppConfig.fromJson(value);
    } on FormatException {
      return AppConfig();
    }
  }

  @override
  Future<void> save(AppConfig config) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _key,
      jsonEncode(config.sanitized().toJson()),
    );
    if (!saved) {
      throw StateError('The platform did not persist application settings');
    }
  }
}

final class MemoryConfigStore implements ConfigStore {
  MemoryConfigStore([AppConfig? value]) : value = value ?? AppConfig();
  AppConfig value;

  @override
  Future<AppConfig> load() async => value;

  @override
  Future<void> save(AppConfig config) async => value = config;
}
