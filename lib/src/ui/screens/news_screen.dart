import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_controller.dart';
import '../../core/app_state.dart';
import '../../models/models.dart';
import '../widgets/dashboard_widgets.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    return FeaturePage(
      title: 'Headlines',
      subtitle:
          'A bounded, deduplicated briefing filtered against your own keywords.',
      actions: [
        FilledButton.icon(
          onPressed: controller.refreshNews,
          icon: controller.loading(OperationLane.news)
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: controller.config.newsKeywords
              .map((keyword) => Chip(label: Text(keyword)))
              .toList(),
        ),
        const SizedBox(height: 18),
        if (controller.newsData.isEmpty)
          EmptyPanel(
            icon: Icons.newspaper,
            title: 'No matching headlines loaded',
            message:
                'Add NEWS_API_KEY as a dart-define, adjust keywords in Settings, and refresh.',
            action: OutlinedButton(
              onPressed: controller.refreshNews,
              child: const Text('Try now'),
            ),
          )
        else
          for (final item in controller.newsData) ...[
            _HeadlineCard(item: item),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({required this.item});
  final NewsItem item;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.read<AppController>().openUri(item.url),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              child: Text(
                item.source.isEmpty
                    ? '?'
                    : item.source.characters.first.toUpperCase(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.description case final description?) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    [
                      item.source,
                      if (item.publishedAt case final date?)
                        DateFormat.yMMMd().add_jm().format(date.toLocal()),
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, size: 18),
          ],
        ),
      ),
    ),
  );
}
