import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_controller.dart';
import '../core/app_state.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const titles = [
    'Start the day in one place',
    'Connect calendar sync',
    'Your settings travel safely',
    'Pick the daily essentials',
    'You are ready',
  ];
  static const descriptions = [
    'Calendar, weather, markets, headlines, tasks, focus sessions, and useful links in one adaptive app.',
    'Use Google, Apple, or Microsoft identity. Google and Microsoft can also provide read-only calendar access.',
    'Local preferences work offline. Optional Supabase sync keeps redacted settings and onboarding progress aligned.',
    'The starter setup includes Chicago weather, a concise market watchlist, and technology, AI, and markets headlines.',
    'Open your dashboard now. Every loading, authentication, and onboarding transition is guarded by the formal state machine.',
  ];
  static const icons = [
    Icons.wb_sunny,
    Icons.event_available,
    Icons.shield_outlined,
    Icons.tune,
    Icons.rocket_launch,
  ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final index = controller.machine.onboarding.pageIndex;
    final compact = MediaQuery.sizeOf(context).width < 760;
    final content = _StepContent(
      index: index,
      controller: controller,
      title: titles[index],
      description: descriptions[index],
      icon: icons[index],
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: compact
                  ? Column(
                      children: [
                        _Progress(index: index),
                        const SizedBox(height: 24),
                        Expanded(child: content),
                      ],
                    )
                  : Row(
                      children: [
                        SizedBox(width: 280, child: _Progress(index: index)),
                        const SizedBox(width: 48),
                        Expanded(child: content),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Happy Wakey',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text('Setup progress', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 18),
          for (var step = 0; step < 5; step += 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: step <= index
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Text('${step + 1}'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(OnboardingScreen.titles[step], maxLines: 2),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _StepContent extends StatelessWidget {
  const _StepContent({
    required this.index,
    required this.controller,
    required this.title,
    required this.description,
    required this.icon,
  });
  final int index;
  final AppController controller;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 24),
      Text(
        title,
        style: Theme.of(context).textTheme.displaySmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 14),
      Text(description, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 28),
      if (index == 1) _LoginButtons(controller: controller),
      if (index == 2)
        const Card(
          child: ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Secrets stay out of preference JSON'),
            subtitle: Text(
              'OAuth sessions use Supabase storage; only redacted app preferences are mirrored.',
            ),
          ),
        ),
      if (index == 3)
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Chip(avatar: Icon(Icons.cloud, size: 18), label: Text('Weather')),
            Chip(
              avatar: Icon(Icons.show_chart, size: 18),
              label: Text('Markets'),
            ),
            Chip(
              avatar: Icon(Icons.newspaper, size: 18),
              label: Text('Headlines'),
            ),
            Chip(
              avatar: Icon(Icons.checklist, size: 18),
              label: Text('Planner'),
            ),
            Chip(avatar: Icon(Icons.timer, size: 18), label: Text('Focus')),
          ],
        ),
      const Spacer(),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton.icon(
            onPressed: index == 0 ? null : controller.onboardingPrevious,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
          ),
          if (index < 4)
            TextButton(
              onPressed: controller.onboardingSkip,
              child: const Text('Skip to ready'),
            ),
          FilledButton.icon(
            onPressed: index == 4
                ? controller.onboardingFinish
                : controller.onboardingNext,
            icon: Icon(index == 4 ? Icons.dashboard : Icons.arrow_forward),
            label: Text(index == 4 ? 'Open dashboard' : 'Continue'),
          ),
        ],
      ),
    ],
  );
}

class _LoginButtons extends StatelessWidget {
  const _LoginButtons({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.supabaseConfigured) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Cloud sign-in is optional'),
          subtitle: Text(
            'Build with SUPABASE_URL and SUPABASE_ANON_KEY dart-defines to enable OAuth.',
          ),
        ),
      );
    }
    final busy = controller.machine.authenticationInProgress;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton(
          onPressed: busy ? null : () => controller.login(AuthProvider.google),
          child: const Text('Google'),
        ),
        OutlinedButton(
          onPressed: busy ? null : () => controller.login(AuthProvider.apple),
          child: const Text('Apple'),
        ),
        OutlinedButton(
          onPressed: busy ? null : () => controller.login(AuthProvider.azure),
          child: const Text('Microsoft'),
        ),
      ],
    );
  }
}
