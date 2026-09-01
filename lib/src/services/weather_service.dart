import '../models/models.dart';
import 'api_client.dart';

final class WeatherService {
  WeatherService(this._api);
  final ApiClient _api;

  Future<WeatherData> fetch(WeatherLocation location) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,is_day',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'temperature_unit': 'fahrenheit',
      'wind_speed_unit': 'mph',
      'precipitation_unit': 'inch',
      'timezone': 'auto',
      'forecast_days': '5',
    });
    final value = await _api.getJson(uri, service: 'Open-Meteo');
    if (value is! Map) {
      throw const ApiException('Open-Meteo returned an invalid object');
    }
    final current = _map(value['current']);
    final daily = _map(value['daily']);
    final times = _list(daily['time']);
    final codes = _list(daily['weather_code']);
    final highs = _list(daily['temperature_2m_max']);
    final lows = _list(daily['temperature_2m_min']);
    final precip = _list(daily['precipitation_probability_max']);
    final count = [
      times.length,
      codes.length,
      highs.length,
      lows.length,
    ].reduce((left, right) => left < right ? left : right);
    return WeatherData(
      locationName: location.name,
      temperature: _number(current['temperature_2m']),
      feelsLike: _number(current['apparent_temperature']),
      condition: conditionForCode(_integer(current['weather_code'])),
      weatherCode: _integer(current['weather_code']),
      humidity: _number(current['relative_humidity_2m']).clamp(0, 100),
      windSpeed: _number(current['wind_speed_10m']),
      precipitation: _number(current['precipitation']),
      isDay: _integer(current['is_day']) == 1,
      observedAt:
          DateTime.tryParse(current['time']?.toString() ?? '') ??
          DateTime.now(),
      forecast: List.generate(count > 5 ? 5 : count, (index) {
        final code = _integer(codes[index]);
        return DailyForecast(
          date: DateTime.tryParse(times[index].toString()) ?? DateTime.now(),
          weatherCode: code,
          condition: conditionForCode(code),
          high: _number(highs[index]),
          low: _number(lows[index]),
          precipitationProbability:
              (index < precip.length ? _number(precip[index]) : 0)
                  .clamp(0, 100)
                  .toDouble(),
        );
      }),
    );
  }

  static String conditionForCode(int code) => switch (code) {
    0 => 'Clear',
    1 || 2 => 'Partly cloudy',
    3 => 'Overcast',
    45 || 48 => 'Fog',
    >= 51 && <= 57 => 'Drizzle',
    >= 61 && <= 67 => 'Rain',
    >= 71 && <= 77 => 'Snow',
    >= 80 && <= 82 => 'Rain showers',
    >= 85 && <= 86 => 'Snow showers',
    >= 95 => 'Thunderstorms',
    _ => 'Conditions unavailable',
  };
}

Map<Object?, Object?> _map(Object? value) => value is Map ? value : const {};
List<Object?> _list(Object? value) => value is List ? value : const [];
double _number(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : 0;
int _integer(Object? value) => value is num ? value.toInt() : 0;
