import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_controller.dart';
import '../../core/app_state.dart';
import '../../models/models.dart';
import '../widgets/dashboard_widgets.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final agenda = controller.agenda;
    return FeaturePage(
      title: 'Calendar command center',
      subtitle: 'A normalized week across Google or Microsoft, with conflicts and reminder scheduling.',
      actions: [
        FilledButton.icon(
          onPressed: controller.machine.isSignedIn
              ? controller.refreshCalendar
              : null,
          icon: controller.loading(OperationLane.calendar)
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          label: const Text('Sync calendar'),
        ),
      ],
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SummaryCard(
              label: 'Week',
              value: '${agenda.totalEvents}',
              detail: 'events',
              icon: Icons.date_range,
            ),
            SummaryCard(
              label: 'Remaining',
              value: '${agenda.remainingEvents}',
              detail: 'upcoming events',
              icon: Icons.upcoming,
            ),
            SummaryCard(
              label: 'Meeting load',
              value: '${agenda.meetingMinutes}',
              detail: 'minutes',
              icon: Icons.groups_outlined,
            ),
            SummaryCard(
              label: 'Conflicts',
              value: '${agenda.conflictCount}',
              detail: agenda.conflictCount == 0
                  ? 'schedule is clear'
                  : 'overlapping events',
              icon: Icons.warning_amber,
              color: agenda.conflictCount == 0 ? Colors.green : Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 22),
        const SectionHeading('Upcoming'),
        if (!controller.machine.isSignedIn)
          const EmptyPanel(
            icon: Icons.login,
            title: 'Sign in to read your calendar',
            message: 'Google and Microsoft logins request read-only calendar scopes.',
          )
        else if (controller.calendarEvents.isEmpty)
          EmptyPanel(
            icon: Icons.event_busy,
            title: 'No events loaded',
            message: 'Sync to load this week, or enjoy the open time.',
            action: OutlinedButton(
              onPressed: controller.refreshCalendar,
              child: const Text('Sync now'),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final event in controller.calendarEvents)
                  _EventTile(event: event),
              ],
            ),
          ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();
    final time = event.allDay
        ? 'All day'
        : '${DateFormat.MMMd().add_jm().format(event.start)} – ${DateFormat.jm().format(event.end)}';
    return ListTile(
      leading: CircleAvatar(
        child: Text(
          event.provider.isEmpty
              ? '?'
              : event.provider.characters.first.toUpperCase(),
        ),
      ),
      title: Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text([time, ?event.location].join(' · ')),
      trailing: event.joinUrl == null
          ? event.eventUrl == null
                ? null
                : IconButton(
                    tooltip: 'Open event',
                    onPressed: () => controller.openUri(event.eventUrl!),
                    icon: const Icon(Icons.open_in_new),
                  )
          : FilledButton.tonal(
              onPressed: () => controller.openUri(event.joinUrl!),
              child: const Text('Join'),
            ),
    );
  }
}
