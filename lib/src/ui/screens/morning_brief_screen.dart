import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_controller.dart';
import '../../core/app_state.dart';
import '../../models/models.dart';
import '../widgets/dashboard_widgets.dart';

class MorningBriefScreen extends StatelessWidget {
  const MorningBriefScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final health = controller.healthData;
    final sleep = health.sleep;
    final steps = health.metric('steps');
    return FeaturePage(
      title: 'Morning brief',
      subtitle:
          'A calm, prioritized start: what needs attention, how your body recovered, and the shape of your day.',
      actions: [
        FilledButton.icon(
          onPressed: controller.refreshBriefing,
          icon:
              controller.loading(OperationLane.inbox) ||
                  controller.loading(OperationLane.directMessages) ||
                  controller.loading(OperationLane.health)
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('Refresh brief'),
        ),
      ],
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SummaryCard(
              label: 'Important email',
              value:
                  '${controller.inboxData.where((item) => item.unread).length}',
              detail: 'unread in the last 7 days',
              icon: Icons.mark_email_unread_outlined,
            ),
            SummaryCard(
              label: 'Direct messages',
              value:
                  '${controller.directMessageData.where((item) => item.unread).length}',
              detail: 'new conversations',
              icon: Icons.forum_outlined,
            ),
            SummaryCard(
              label: 'Sleep result',
              value: sleep?.durationLabel ?? '—',
              detail: sleep == null
                  ? 'Connect Apple Health or Health Connect'
                  : 'deep ${sleep.deepMinutes}m · REM ${sleep.remMinutes}m',
              icon: Icons.bedtime_outlined,
            ),
            SummaryCard(
              label: 'Steps',
              value: steps == null ? '—' : steps.value.round().toString(),
              detail: steps == null ? 'No activity record yet' : 'today so far',
              icon: Icons.directions_walk_outlined,
            ),
          ],
        ),
        const SizedBox(height: 22),
        SectionHeading(
          'Important email',
          action: TextButton(
            onPressed: controller.machine.isSignedIn
                ? controller.refreshInbox
                : null,
            child: const Text('Refresh'),
          ),
        ),
        if (!controller.machine.isSignedIn)
          const EmptyPanel(
            icon: Icons.mail_outline,
            title: 'Sign in to read important email',
            message:
                'Google and Microsoft sign-in request read-only mail access. Messages are ranked locally and never written back.',
          )
        else if (controller.inboxData.isEmpty)
          const EmptyPanel(
            icon: Icons.mark_email_read_outlined,
            title: 'Inbox is clear',
            message:
                'No recent unread messages were returned, or the provider needs a fresh sign-in with mail access.',
          )
        else
          Card(
            child: Column(
              children: [
                for (final item in controller.inboxData) _InboxTile(item: item),
              ],
            ),
          ),
        const SizedBox(height: 22),
        SectionHeading(
          'Direct messages',
          action: TextButton(
            onPressed: controller.machine.isSignedIn
                ? controller.refreshDirectMessages
                : null,
            child: const Text('Refresh'),
          ),
        ),
        if (!controller.machine.isSignedIn)
          const EmptyPanel(
            icon: Icons.forum_outlined,
            title: 'Sign in to read direct messages',
            message:
                'Connect an approved Slack, Discord, Teams, or social source through the Happy Wakey platform gateway.',
          )
        else if (controller.directMessageData.isEmpty)
          const EmptyPanel(
            icon: Icons.mark_chat_read_outlined,
            title: 'No new conversations',
            message:
                'The direct-message gateway is optional and remains empty until a provider connection is consented.',
          )
        else
          Card(
            child: Column(
              children: [
                for (final item in controller.directMessageData)
                  _DirectMessageTile(item: item),
              ],
            ),
          ),
        const SizedBox(height: 22),
        SectionHeading(
          'Sleep and biometrics',
          action: TextButton.icon(
            onPressed: controller.loading(OperationLane.health)
                ? null
                : controller.requestHealthAccess,
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('Connect health data'),
          ),
        ),
        _HealthPanel(snapshot: health),
      ],
    );
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({required this.item});

  final InboxItem item;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();
    final sender = item.senderName.isEmpty
        ? item.senderAddress
        : item.senderName;
    return ListTile(
      leading: CircleAvatar(
        child: Text(
          item.source.isEmpty
              ? '?'
              : item.source.characters.first.toUpperCase(),
        ),
      ),
      title: Text(
        item.subject.isEmpty ? '(no subject)' : item.subject,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          sender,
          item.preview,
          DateFormat.MMMd().add_jm().format(item.receivedAt),
        ].where((part) => part.trim().isNotEmpty).join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: item.url == null
          ? null
          : IconButton(
              tooltip: 'Open message',
              onPressed: () => controller.openUri(item.url!),
              icon: const Icon(Icons.open_in_new),
            ),
    );
  }
}

class _DirectMessageTile extends StatelessWidget {
  const _DirectMessageTile({required this.item});

  final DirectMessage item;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();
    return ListTile(
      leading: CircleAvatar(
        child: Text(
          item.source.isEmpty
              ? '?'
              : item.source.characters.first.toUpperCase(),
        ),
      ),
      title: Text(
        item.conversation.isEmpty ? item.senderName : item.conversation,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          item.senderName,
          item.preview,
          DateFormat.MMMd().add_jm().format(item.receivedAt),
        ].where((part) => part.trim().isNotEmpty).join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: item.url == null
          ? null
          : IconButton(
              tooltip: 'Open conversation',
              onPressed: () => controller.openUri(item.url!),
              icon: const Icon(Icons.open_in_new),
            ),
    );
  }
}

class _HealthPanel extends StatelessWidget {
  const _HealthPanel({required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final sleep = snapshot.sleep;
    if (!snapshot.supported || !snapshot.authorized) {
      return EmptyPanel(
        icon: snapshot.supported
            ? Icons.health_and_safety_outlined
            : Icons.phone_android_outlined,
        title: snapshot.supported
            ? 'Health access is not connected'
            : 'Health data is mobile-only',
        message: snapshot.message,
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(snapshot.message),
            if (sleep != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.bedtime_outlined),
                  const SizedBox(width: 10),
                  Text(
                    sleep.durationLabel,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'deep ${sleep.deepMinutes}m · REM ${sleep.remMinutes}m · awake ${sleep.awakeMinutes}m',
                  ),
                ],
              ),
            ],
            if (snapshot.metrics.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 18,
                runSpacing: 10,
                children: [
                  for (final metric in snapshot.metrics)
                    Text('${_label(metric.kind)}: ${_format(metric)}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _label(String kind) => switch (kind) {
  'active_energy' => 'Active energy',
  'heart_rate' => 'Heart rate',
  'resting_heart_rate' => 'Resting heart rate',
  'blood_oxygen' => 'Blood oxygen',
  'steps' => 'Steps',
  _ => kind,
};

String _format(HealthMetric metric) =>
    '${metric.value.round()} ${metric.unit}'.trim();
