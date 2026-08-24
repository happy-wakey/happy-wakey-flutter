import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_wakey/src/models/models.dart';
import 'package:happy_wakey/src/services/api_client.dart';
import 'package:happy_wakey/src/services/news_service.dart';
import 'package:happy_wakey/src/services/stock_service.dart';
import 'package:happy_wakey/src/services/weather_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('weather service normalizes and bounds Open-Meteo data', () async {
    final api = ApiClient(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'current': {
              'temperature_2m': 71.4,
              'apparent_temperature': 70.1,
              'relative_humidity_2m': 140,
              'precipitation': 0,
              'weather_code': 2,
              'wind_speed_10m': 8.2,
              'is_day': 1,
              'time': '2026-08-24T09:00',
            },
            'daily': {
              'time': List.generate(7, (index) => '2026-08-${24 + index}'),
              'weather_code': [0, 2, 3, 61, 95, 0, 0],
              'temperature_2m_max': [80, 81, 79, 74, 72, 75, 77],
              'temperature_2m_min': [60, 61, 62, 58, 57, 59, 60],
              'precipitation_probability_max': [0, 10, 20, 80, 120, 0, 0],
            },
          }),
          200,
        ),
      ),
    );
    final data = await WeatherService(api).fetch(
      const WeatherLocation(
        name: 'Chicago',
        latitude: 41.8781,
        longitude: -87.6298,
      ),
    );
    expect(data.temperature, 71.4);
    expect(data.humidity, 100);
    expect(data.condition, 'Partly cloudy');
    expect(data.forecast, hasLength(5));
    expect(data.forecast.last.precipitationProbability, 100);
  });

  test(
    'stock service normalizes symbols and keeps credentials in headers',
    () async {
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.url.queryParameters['symbol'], 'AAPL');
          expect(request.url.query, isNot(contains('test-key')));
          expect(request.headers['X-Finnhub-Token'], 'test-key');
          return http.Response(
            jsonEncode({'c': 230.25, 'd': 1.5, 'dp': 0.66, 'h': 232, 'l': 226}),
            200,
          );
        }),
      );
      final quote = await StockService(api, apiKey: 'test-key').fetch(' aapl ');
      expect(quote.symbol, 'AAPL');
      expect(quote.price, 230.25);
      await expectLater(
        StockService(api, apiKey: 'test-key').fetch('<script>'),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test(
    'news service locally filters, validates, deduplicates, and bounds articles',
    () async {
      final articles = <Map<String, Object?>>[
        {
          'title': 'AI improves weather models',
          'description': 'A useful technology report',
          'url': 'https://example.com/one',
          'urlToImage': 'javascript:alert(1)',
          'publishedAt': '2026-08-24T12:00:00Z',
          'source': {'name': 'Example'},
        },
        {
          'title': 'Duplicate',
          'url': 'https://example.com/one',
          'source': {'name': 'Example'},
        },
        {
          'title': 'Unrelated sports result',
          'url': 'https://example.com/two',
          'source': {'name': 'Example'},
        },
        {
          'title': 'AI on an unsafe URL',
          'url': 'file:///private/data',
          'source': {'name': 'Example'},
        },
      ];
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.headers['X-Api-Key'], 'news-key');
          return http.Response(jsonEncode({'articles': articles}), 200);
        }),
      );
      final result = await NewsService(api, apiKey: 'news-key').fetch(['AI']);
      expect(result, hasLength(1));
      expect(result.single.title, 'AI improves weather models');
      expect(result.single.imageUrl, isNull);
    },
  );
}
