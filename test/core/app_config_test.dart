import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_wakey/src/core/app_config.dart';
import 'package:happy_wakey/src/core/app_state.dart';

void main() {
  test('default config provides the daily essentials without secrets', () {
    final config = AppConfig();
    expect(config.weatherLocations, isNotEmpty);
    expect(config.stockSymbols, contains('AAPL'));
    expect(config.newsKeywords, isNotEmpty);
    expect(config.browserBookmarks, hasLength(2));
    final encoded = jsonEncode(config.toJson()).toLowerCase();
    expect(encoded, isNot(contains('token')));
    expect(encoded, isNot(contains('secret')));
    expect(encoded, isNot(contains('api_key')));
  });

  test('deserialization sanitizes untrusted persisted values', () {
    final config = AppConfig.fromJson({
      'weather_locations': [
        {'name': 'Impossible', 'lat': 1000, 'lon': 1000},
      ],
      'stock_symbols': [' aapl ', 'AAPL', '<script>', 'MSFT'],
      'news_keywords': List.generate(30, (index) => 'keyword-$index'),
      'focus_minutes': 999,
      'onboarding': {
        'completed': false,
        'current_step': 'made-up-step',
        'step_index': 42,
      },
    });
    expect(config.weatherLocations, isEmpty);
    expect(config.stockSymbols, ['AAPL', 'MSFT']);
    expect(config.newsKeywords, hasLength(20));
    expect(config.focusMinutes, 120);
    expect(config.onboarding.step, OnboardingStep.welcome);
  });

  test('completed onboarding persists its irreversible witness', () {
    final value = OnboardingConfig.fromStep(OnboardingStep.complete);
    final decoded = OnboardingConfig.fromJson(value.toJson());
    expect(decoded.completed, isTrue);
    expect(decoded.step, OnboardingStep.complete);
  });
}
