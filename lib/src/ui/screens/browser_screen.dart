import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_controller.dart';
import '../widgets/dashboard_widgets.dart';

class BrowserScreen extends StatelessWidget {
  const BrowserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    return FeaturePage(
      title: 'Useful links',
      subtitle:
          'Open trusted web destinations in the system browser; embedded credentials and unsafe schemes are rejected.',
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final bookmark in controller.config.browserBookmarks)
              SizedBox(
                width: 320,
                child: Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.public)),
                    title: Text(bookmark.title),
                    subtitle: Text(bookmark.url.host),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => controller.openUri(bookmark.url),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        const Card(
          child: ListTile(
            leading: Icon(Icons.security),
            title: Text('External-by-default browsing'),
            subtitle: Text(
              'Happy Wakey hands links to your platform browser so its sandbox, passwords, and privacy controls remain authoritative.',
            ),
          ),
        ),
      ],
    );
  }
}
