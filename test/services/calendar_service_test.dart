import 'package:flutter_test/flutter_test.dart';
import 'package:happy_wakey/src/models/models.dart';
import 'package:happy_wakey/src/services/calendar_service.dart';

void main() {
  test(
    'agenda computes remaining meetings, load, conflicts, and next event',
    () {
      final now = DateTime(2026, 8, 24, 9);
      final events = [
        _event(
          'planning',
          now.add(const Duration(hours: 1)),
          const Duration(hours: 1),
        ),
        _event(
          'overlap',
          now.add(const Duration(hours: 1, minutes: 30)),
          const Duration(hours: 1),
        ),
        _event(
          'later',
          now.add(const Duration(hours: 4)),
          const Duration(minutes: 30),
        ),
        _event(
          'tomorrow',
          now.add(const Duration(days: 1)),
          const Duration(minutes: 30),
        ),
      ];
      final agenda = CalendarService.agenda(events, now: now);
      expect(agenda.totalEvents, 3);
      expect(agenda.remainingEvents, 3);
      expect(agenda.meetingMinutes, 150);
      expect(agenda.conflictCount, 1);
      expect(agenda.nextEvent?.title, 'planning');
    },
  );
}

CalendarEvent _event(String title, DateTime start, Duration duration) =>
    CalendarEvent(
      id: title,
      title: title,
      start: start,
      end: start.add(duration),
      allDay: false,
      provider: 'test',
      status: 'confirmed',
    );
