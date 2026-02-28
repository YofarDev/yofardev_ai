import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/services/llm/fake_llm_service.dart';
import '../bloc/demo_cubit.dart';
import '../widgets/demo_controls_widget.dart';

/// Demo controls page for managing demo mode
///
/// Only accessible in debug mode or via hidden settings
class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  static const String routeName = '/demo';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo Controls'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          _ServiceSwitcher(),
          SizedBox(height: 16),
          DemoControlsWidget(),
        ],
      ),
    );
  }
}

/// Widget to switch between real and fake LLM service
class _ServiceSwitcher extends StatelessWidget {
  const _ServiceSwitcher();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DemoCubit, DemoState>(
      builder: (BuildContext context, DemoState state) {
        final bool isUsingFake = getIt<FakeLlmService>().isActive;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      isUsingFake ? Icons.science : Icons.cloud,
                      color: isUsingFake ? Colors.orange : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'LLM Service',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            isUsingFake ? 'Fake (Demo Mode)' : 'Real (API)',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isUsingFake
                                      ? Colors.orange
                                      : Colors.blue,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isUsingFake,
                      onChanged: (bool value) {
                        _switchService(context, value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isUsingFake
                      ? 'Using pre-scripted responses. No API calls will be made.'
                      : 'Using real LLM API. Requires valid configuration.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _switchService(BuildContext context, bool useFake) {
    switchLlmService(useFake);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          useFake
              ? 'Switched to Fake LLM Service'
              : 'Switched to Real LLM Service',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
