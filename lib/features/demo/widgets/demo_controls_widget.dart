import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yofardev_ai/features/demo/bloc/demo_cubit.dart';
import 'package:yofardev_ai/features/demo/models/demo_script.dart';

/// Demo controls widget for selecting and starting demos
///
/// Only visible in debug mode or via hidden settings
class DemoControlsWidget extends StatelessWidget {
  const DemoControlsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DemoCubit, DemoState>(
      builder: (BuildContext context, DemoState state) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.theater_comedy),
                    const SizedBox(width: 8),
                    Text(
                      'Demo Mode',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (state.isActive) ...<Widget>[
                  _ActiveDemoInfo(state: state),
                ] else ...<Widget>[
                  _DemoScriptList(state: state),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActiveDemoInfo extends StatelessWidget {
  final DemoState state;

  const _ActiveDemoInfo({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (state.currentScript != null)
          Text(
            'Running: ${state.currentScript!.name}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        const SizedBox(height: 8),
        Text(
          'Responses remaining: ${state.remainingResponses}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            FilledButton.icon(
              onPressed: () => _resetDemo(context),
              icon: const Icon(Icons.stop),
              label: const Text('Stop Demo'),
            ),
          ],
        ),
      ],
    );
  }

  void _resetDemo(BuildContext context) {
    context.read<DemoCubit>().resetDemo();
    // Also deactivate the demo service
    // This would be done via the service
  }
}

class _DemoScriptList extends StatelessWidget {
  final DemoState state;

  const _DemoScriptList({required this.state});

  @override
  Widget build(BuildContext context) {
    final List<DemoScript> scripts = DemoScripts.all;

    if (scripts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No demo scripts available'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Available Demos',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        ...scripts.map((DemoScript script) => _DemoScriptTile(
              script: script,
            )),
      ],
    );
  }
}

class _DemoScriptTile extends StatelessWidget {
  final DemoScript script;

  const _DemoScriptTile({required this.script});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.play_arrow),
      title: Text(script.name),
      subtitle: Text(script.description),
      trailing: Text('${script.responses.length} responses'),
      onTap: () => _startDemo(context, script),
    );
  }

  void _startDemo(BuildContext context, DemoScript script) {
    // This would integrate with the DemoService
    // For now, just update the cubit state
    context.read<DemoCubit>().startDemo(script);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting demo: ${script.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
