import 'dart:io' show Platform;

import 'package:health/health.dart';

import '../models/models.dart';

/// Mobile adapter for Apple HealthKit and Google Health Connect.
///
/// Only read permissions are requested. The app aggregates a short window
/// locally and exposes the source name so the user can see where each value
/// came from; raw health records never enter the settings or sync document.
final class HealthService {
  HealthService({Health? health}) : _health = health ?? Health();

  final Health _health;

  bool get supported => Platform.isIOS || Platform.isAndroid;

  static const _types = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE,
  ];

  Future<HealthSnapshot> readToday({bool requestAccess = false}) async {
    if (!supported) {
      return const HealthSnapshot.unavailable(
        'Health data is available on iOS and Android only',
      );
    }
    try {
      await _health.configure();
      var authorized = await _health.hasPermissions(_types) == true;
      if (!authorized && requestAccess) {
        authorized = await _health.requestAuthorization(
          _types,
          permissions: List.filled(_types.length, HealthDataAccess.READ),
        );
      }
      if (!authorized) {
        return const HealthSnapshot(
          supported: true,
          authorized: false,
          message: 'Allow read access to show sleep and activity results',
          metrics: [],
          source: 'none',
        );
      }
      final now = DateTime.now();
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(hours: 12));
      final points = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: start,
        endTime: now,
      );
      return _aggregate(points, now);
    } catch (error) {
      return HealthSnapshot(
        supported: true,
        authorized: false,
        message: 'Health data could not be read safely: $error',
        metrics: const [],
        source: Platform.isIOS ? 'apple_health' : 'health_connect',
      );
    }
  }
}

HealthSnapshot _aggregate(List<HealthDataPoint> points, DateTime now) {
  final source = points.isEmpty
      ? 'none'
      : points.first.sourcePlatform.name == 'appleHealth'
      ? 'apple_health'
      : 'health_connect';
  final metrics = <HealthMetric>[];
  for (final type in const [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
  ]) {
    final values = points
        .where((point) => point.type == type)
        .map(_numeric)
        .whereType<_HealthValue>()
        .toList();
    if (values.isEmpty) continue;
    final aggregate =
        type == HealthDataType.STEPS ||
            type == HealthDataType.ACTIVE_ENERGY_BURNED
        ? values.fold<double>(0, (sum, value) => sum + value.value)
        : (values..sort((left, right) => left.at.compareTo(right.at)))
              .last
              .value;
    final latest = values..sort((left, right) => left.at.compareTo(right.at));
    final unit = switch (type) {
      HealthDataType.STEPS => 'steps',
      HealthDataType.ACTIVE_ENERGY_BURNED => 'kcal',
      HealthDataType.HEART_RATE => 'bpm',
      HealthDataType.RESTING_HEART_RATE => 'bpm',
      HealthDataType.BLOOD_OXYGEN => '%',
      _ => 'value',
    };
    metrics.add(
      HealthMetric(
        kind: _kind(type),
        value: aggregate,
        unit: unit,
        measuredAt: latest.last.at,
        source: source,
      ),
    );
  }

  int minutes(HealthDataType type) => points
      .where((point) => point.type == type)
      .map(_numeric)
      .whereType<_HealthValue>()
      .fold<double>(0, (sum, value) => sum + value.value)
      .round()
      .clamp(0, 24 * 60)
      .toInt();

  final asleep = minutes(HealthDataType.SLEEP_ASLEEP);
  final deep = minutes(HealthDataType.SLEEP_DEEP);
  final rem = minutes(HealthDataType.SLEEP_REM);
  final awake = minutes(HealthDataType.SLEEP_AWAKE);
  final sleep = asleep == 0 && deep == 0 && rem == 0 && awake == 0
      ? null
      : SleepSummary(
          date: DateTime(now.year, now.month, now.day),
          durationMinutes: asleep,
          deepMinutes: deep,
          remMinutes: rem,
          awakeMinutes: awake,
          source: source,
        );
  return HealthSnapshot(
    supported: true,
    authorized: true,
    message: points.isEmpty
        ? 'Health access is connected; no recent records were found'
        : 'Updated from ${source == 'apple_health' ? 'Apple Health' : 'Health Connect'}',
    metrics: metrics,
    source: source,
    sleep: sleep,
  );
}

String _kind(HealthDataType type) => switch (type) {
  HealthDataType.STEPS => 'steps',
  HealthDataType.ACTIVE_ENERGY_BURNED => 'active_energy',
  HealthDataType.HEART_RATE => 'heart_rate',
  HealthDataType.RESTING_HEART_RATE => 'resting_heart_rate',
  HealthDataType.BLOOD_OXYGEN => 'blood_oxygen',
  _ => type.name.toLowerCase(),
};

_HealthValue? _numeric(HealthDataPoint point) {
  final value = point.value;
  if (value is! NumericHealthValue || !value.numericValue.isFinite) {
    return null;
  }
  return _HealthValue(value.numericValue.toDouble(), point.dateTo);
}

final class _HealthValue {
  const _HealthValue(this.value, this.at);

  final double value;
  final DateTime at;
}
