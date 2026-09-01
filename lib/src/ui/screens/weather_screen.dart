import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_controller.dart';
import '../../core/app_state.dart';
import '../../models/models.dart';
import '../widgets/dashboard_widgets.dart';

class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    return FeaturePage(
      title: 'Weather',
      subtitle: 'Live conditions and a seven-day Open-Meteo forecast for every saved location.',
      actions: [
        FilledButton.icon(
          onPressed: controller.refreshWeather,
          icon: controller.loading(OperationLane.weather)
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
      children: [
        if (controller.weatherData.isEmpty)
          EmptyPanel(
            icon: Icons.cloud_outlined,
            title: 'No live weather yet',
            message: 'Refresh for current conditions. Locations can be changed in Settings.',
            action: OutlinedButton(
              onPressed: controller.refreshWeather,
              child: const Text('Load weather'),
            ),
          )
        else
          for (final weather in controller.weatherData) ...[
            _WeatherPanel(weather: weather),
            const SizedBox(height: 18),
          ],
      ],
    );
  }
}

class _WeatherPanel extends StatelessWidget {
  const _WeatherPanel({required this.weather});
  final WeatherData weather;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                _icon(weather.weatherCode, weather.isDay),
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weather.locationName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    '${weather.temperature.round()}°F · ${weather.condition}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Feels like ${weather.feelsLike.round()}° · Humidity ${weather.humidity.round()}% · Wind ${weather.windSpeed.round()} mph',
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 32),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final day in weather.forecast)
                  SizedBox(
                    width: 130,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          Text(
                            DateFormat.E().format(day.date),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Icon(_icon(day.weatherCode, true)),
                          const SizedBox(height: 6),
                          Text('${day.high.round()}° / ${day.low.round()}°'),
                          Text('${day.precipitationProbability.round()}% rain'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  IconData _icon(int code, bool isDay) {
    if (code == 0) return isDay ? Icons.wb_sunny : Icons.nightlight_round;
    if (code <= 3) return Icons.cloud_queue;
    if (code <= 48) return Icons.foggy;
    if (code <= 67 || code >= 80 && code <= 82) return Icons.umbrella;
    if (code <= 77 || code >= 85 && code <= 86) return Icons.ac_unit;
    return Icons.thunderstorm;
  }
}
