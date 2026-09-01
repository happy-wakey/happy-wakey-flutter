import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_controller.dart';
import '../../core/app_state.dart';
import '../../models/models.dart';
import '../widgets/dashboard_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _locationName = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _symbols = TextEditingController();
  final _keywords = TextEditingController();
  final _focusMinutes = TextEditingController();
  bool _loaded = false;
  bool _localReminders = true;
  bool _cloudReminders = false;
  bool _cloudSync = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final config = context.read<AppController>().config;
    final location = config.weatherLocations.firstOrNull;
    _locationName.text = location?.name ?? '';
    _latitude.text = location?.latitude.toString() ?? '';
    _longitude.text = location?.longitude.toString() ?? '';
    _symbols.text = config.stockSymbols.join(', ');
    _keywords.text = config.newsKeywords.join(', ');
    _focusMinutes.text = config.focusMinutes.toString();
    _localReminders = config.reminderSettings.enabled;
    _cloudReminders = config.reminderSettings.cloudEmailEnabled;
    _cloudSync = config.supabaseSyncEnabled;
    _loaded = true;
  }

  @override
  void dispose() {
    _locationName.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _symbols.dispose();
    _keywords.dispose();
    _focusMinutes.dispose();
    super.dispose();
  }

  Future<void> _save(AppController controller) async {
    final latitude = double.tryParse(_latitude.text);
    final longitude = double.tryParse(_longitude.text);
    final locations =
        latitude == null ||
            longitude == null ||
            _locationName.text.trim().isEmpty
        ? const <WeatherLocation>[]
        : [
            WeatherLocation(
              name: _locationName.text.trim(),
              latitude: latitude,
              longitude: longitude,
            ),
          ];
    await controller.updateConfig(
      controller.config.copyWith(
        weatherLocations: locations,
        stockSymbols: _csv(_symbols.text),
        newsKeywords: _csv(_keywords.text),
        supabaseSyncEnabled: _cloudSync,
        focusMinutes: int.tryParse(_focusMinutes.text) ?? 25,
        reminderSettings: controller.config.reminderSettings.copyWith(
          enabled: _localReminders,
          cloudEmailEnabled: _cloudReminders,
        ),
      ),
    );
  }

  List<String> _csv(String value) => value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final session = controller.session;
    return FeaturePage(
      title: 'Settings and diagnostics',
      subtitle: 'Preferences are local-first. Credentials are compile-time or encrypted session material and never enter settings JSON.',
      actions: [
        FilledButton.icon(
          onPressed: () => _save(controller),
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),
      ],
      children: [
        const SectionHeading('Account'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    session == null
                        ? Icons.person_outline
                        : Icons.verified_user,
                  ),
                  title: Text(
                    session == null
                        ? 'Not signed in'
                        : session.email.isEmpty
                        ? session.userId
                        : session.email,
                  ),
                  subtitle: Text(
                    !controller.supabaseConfigured
                        ? 'Cloud identity is not configured for this build.'
                        : session == null
                        ? 'Sign in for calendar and optional preference sync.'
                        : 'Provider: ${session.provider.isEmpty ? 'Supabase' : session.provider}',
                  ),
                ),
                if (session == null && controller.supabaseConfigured)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => controller.login(AuthProvider.google),
                        child: const Text('Google'),
                      ),
                      OutlinedButton(
                        onPressed: () => controller.login(AuthProvider.apple),
                        child: const Text('Apple'),
                      ),
                      OutlinedButton(
                        onPressed: () => controller.login(AuthProvider.azure),
                        child: const Text('Microsoft'),
                      ),
                    ],
                  )
                else if (session != null)
                  OutlinedButton.icon(
                    onPressed: controller.logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const SectionHeading('Daily sources'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                TextField(
                  controller: _locationName,
                  decoration: const InputDecoration(
                    labelText: 'Weather location name',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latitude,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _longitude,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _symbols,
                  decoration: const InputDecoration(
                    labelText: 'Market symbols',
                    helperText: 'Comma-separated, e.g. AAPL, MSFT, SPY',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _keywords,
                  decoration: const InputDecoration(
                    labelText: 'News keywords',
                    helperText: 'Comma-separated and locally enforced',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _focusMinutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Focus duration in minutes (5–120)',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const SectionHeading('Reminders and sync'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: _localReminders,
                onChanged: (value) => setState(() => _localReminders = value),
                title: const Text('Local calendar reminders'),
                subtitle: const Text(
                  'Schedules bounded notifications on this device.',
                ),
              ),
              SwitchListTile(
                value: _cloudReminders,
                onChanged: controller.machine.isSignedIn
                    ? (value) => setState(() => _cloudReminders = value)
                    : null,
                title: const Text('Cloud email reminders'),
                subtitle: const Text(
                  'Requires sign-in, shared-auth exchange, and the configured reminder gateway.',
                ),
              ),
              SwitchListTile(
                value: _cloudSync,
                onChanged: (value) => setState(() => _cloudSync = value),
                title: const Text('Supabase preference sync'),
                subtitle: const Text(
                  'Syncs redacted preferences only; session secrets never enter the document.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: controller.testNotification,
                      icon: const Icon(Icons.notifications_active),
                      label: const Text('Test local reminder'),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.machine.isSignedIn
                          ? controller.testCloudNotification
                          : null,
                      icon: const Icon(Icons.mark_email_read_outlined),
                      label: const Text('Test cloud reminder'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionHeading('Formal state diagnostics'),
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: const Text('Current validated machine snapshot'),
            subtitle: const Text(
              'Every accepted transition preserves the runtime invariants; stale completions stutter.',
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: SizedBox(
                  width: double.infinity,
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ')
                        .convert(jsonDecode(controller.machine.toJson())),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
