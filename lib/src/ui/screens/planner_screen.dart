import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_controller.dart';
import '../widgets/dashboard_widgets.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final _task = TextEditingController();

  @override
  void dispose() {
    _task.dispose();
    super.dispose();
  }

  Future<void> _add(AppController controller) async {
    final value = _task.text;
    if (value.trim().isEmpty) return;
    _task.clear();
    await controller.addTask(value);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final tasks = controller.config.tasks;
    return FeaturePage(
      title: 'Daily planner',
      subtitle:
          'A focused local-first list—small enough to finish, durable enough to survive a restart.',
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _task,
                    maxLength: 160,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(controller),
                    decoration: const InputDecoration(
                      labelText: 'What matters today?',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _add(controller),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (tasks.isEmpty)
          const EmptyPanel(
            icon: Icons.task_alt,
            title: 'A clear slate',
            message: 'Add one concrete task to begin your day.',
          )
        else
          Card(
            child: Column(
              children: [
                for (final task in tasks)
                  CheckboxListTile(
                    value: task.completed,
                    onChanged: (_) => controller.toggleTask(task.id),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    secondary: IconButton(
                      tooltip: 'Remove task',
                      onPressed: () => controller.removeTask(task.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
