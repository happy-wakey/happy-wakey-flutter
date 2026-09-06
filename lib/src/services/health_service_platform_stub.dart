import '../models/models.dart';

/// Web and unsupported-platform implementation. Health data stays opt-in and
/// never falls back to fabricated values.
final class HealthService {
  const HealthService();

  bool get supported => false;

  Future<HealthSnapshot> readToday({bool requestAccess = false}) async =>
      const HealthSnapshot.unavailable(
        'Apple Health and Google Health Connect are available on mobile only',
      );
}
