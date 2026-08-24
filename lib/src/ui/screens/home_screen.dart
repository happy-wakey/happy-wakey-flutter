import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_controller.dart';
import '../../core/app_state.dart';
import '../widgets/dashboard_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final agenda = controller.agenda;
    final weather = controller.weatherData.firstOrNull;
    final nextEvent = agenda.nextEvent;
    final openTasks = controller.config.tasks
        .where((task) => !task.completed)
        .length;
    return FeaturePage(
      title: _greeting(),
      subtitle: DateFormat('EEEE, MMMM d').format(DateTime.now()),
      actions: [
        FilledButton.icon(
          onPressed: controller.refreshAll,
          icon: controller.loading(OperationLane.weather)
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('Refresh day'),
        ),
      ],
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SummaryCard(
              label: 'Next event',
              value: nextEvent == null
                  ? 'Clear'
                  : nextEvent.allDay
                  ? 'All day'
                  : DateFormat.jm().format(nextEvent.start),
              detail: nextEvent?.title ?? 'Nothing scheduled next',
              icon: Icons.event_available,
            ),
            SummaryCard(
              label: weather?.locationName ?? 'Weather',
              value: weather == null ? '—' : '${weather.temperature.round()}°',
              detail: weather?.condition ?? 'Refresh for live conditions',
              icon: Icons.wb_sunny_outlined,
            ),
            SummaryCard(
              label: 'Today',
              value: '${agenda.remainingEvents}',
              detail: '${agenda.meetingMinutes} min in meetings',
              icon: Icons.schedule,
            ),
            SummaryCard(
              label: 'Open tasks',
              value: '$openTasks',
              detail: '${controller.config.tasks.length - openTasks} completed',
              icon: Icons.check_circle_outline,
            ),
          ],
        ),
        const SizedBox(height: 22),
        const SectionHeading('Jump back in'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            _JumpCard(
              destination: 1,
              icon: Icons.calendar_month,
              title: 'Plan around your calendar',
              detail: 'Conflicts, meeting load, and join links',
            ),
            _JumpCard(
              destination: 5,
              icon: Icons.checklist,
              title: 'Choose the important work',
              detail: 'A small, durable daily task list',
            ),
            _JumpCard(
              destination: 6,
              icon: Icons.timer,
              title: 'Start a focus block',
              detail: 'A guarded pause-and-resume timer',
            ),
          ],
        ),
        if (!controller.machine.isSignedIn) ...[
          const SizedBox(height: 22),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_off_outlined),
              title: const Text('Calendar and cloud sync are offline'),
              subtitle: const Text(
                'Sign in from Settings when Supabase OAuth is configured. Everything else remains local-first.',
              ),
              trailing: TextButton(
                onPressed: () => controller.selectDestination(8),
                child: const Text('Settings'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

class _JumpCard extends StatelessWidget {
  const _JumpCard({
    required this.destination,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final int destination;
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 340,
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () =>
            context.read<AppController>().selectDestination(destination),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(child: Icon(icon)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(detail),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    ),
  );
}
