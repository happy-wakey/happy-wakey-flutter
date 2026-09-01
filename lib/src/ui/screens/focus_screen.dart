import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_controller.dart';
import '../../core/focus_state.dart';
import '../widgets/dashboard_widgets.dart';

class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final focus = controller.focus;
    final remaining = focus.remaining;
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return FeaturePage(
      title: 'Focus',
      subtitle: 'A second explicit state machine governs start, pause, resume, completion, and reset.',
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    SizedBox.square(
                      dimension: 230,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: focus.progress,
                            strokeWidth: 14,
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  focus.phase == FocusPhase.idle
                                      ? '${controller.config.focusMinutes}:00'
                                      : '$minutes:$seconds',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  focus.phase.name.toUpperCase(),
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        if (focus.phase == FocusPhase.idle ||
                            focus.phase == FocusPhase.completed)
                          FilledButton.icon(
                            onPressed: controller.startFocus,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start focus'),
                          ),
                        if (focus.phase == FocusPhase.running)
                          FilledButton.icon(
                            onPressed: controller.pauseFocus,
                            icon: const Icon(Icons.pause),
                            label: const Text('Pause'),
                          ),
                        if (focus.phase == FocusPhase.paused)
                          FilledButton.icon(
                            onPressed: controller.resumeFocus,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Resume'),
                          ),
                        OutlinedButton.icon(
                          onPressed: controller.resetFocus,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
