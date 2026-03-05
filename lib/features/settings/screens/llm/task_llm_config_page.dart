import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/res/app_colors.dart';
import '../../../../core/models/task_llm_config.dart';
import '../../../../core/models/llm_config.dart';
import '../../bloc/settings_cubit.dart';
import '../../bloc/settings_state.dart';

/// Settings page for configuring task-specific LLM mappings
class TaskLlmConfigPage extends StatefulWidget {
  const TaskLlmConfigPage({super.key});

  @override
  State<TaskLlmConfigPage> createState() => _TaskLlmConfigPageState();
}

class _TaskLlmConfigPageState extends State<TaskLlmConfigPage> {
  @override
  void initState() {
    super.initState();
    // Load configs on page load
    context.read<SettingsCubit>().loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (BuildContext context, SettingsState state) {
        final TaskLlmConfig taskConfig =
            state.taskLlmConfig ?? const TaskLlmConfig();
        final List<LlmConfig> availableConfigs = state.availableLlmConfigs;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Task LLM Configuration'),
            backgroundColor: Colors.transparent,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _buildTaskDropdown(
                label: 'Assistant',
                description: 'LLM used for main chat responses',
                currentId: taskConfig.assistantLlmId,
                availableConfigs: availableConfigs,
                onChanged: (String? id) => _updateTaskConfig(
                  context,
                  taskConfig.copyWith(assistantLlmId: id),
                ),
              ),

              const SizedBox(height: 16),

              _buildTaskDropdown(
                label: 'Title Generation',
                description: 'LLM used to generate chat titles',
                currentId: taskConfig.titleGenerationLlmId,
                availableConfigs: availableConfigs,
                onChanged: (String? id) => _updateTaskConfig(
                  context,
                  taskConfig.copyWith(titleGenerationLlmId: id),
                ),
              ),

              const SizedBox(height: 16),

              _buildTaskDropdown(
                label: 'Function Calling',
                description: 'LLM used for tool/function detection',
                currentId: taskConfig.functionCallingLlmId,
                availableConfigs: availableConfigs,
                onChanged: (String? id) => _updateTaskConfig(
                  context,
                  taskConfig.copyWith(functionCallingLlmId: id),
                ),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Note: If no LLM is selected for a task, the default assistant LLM will be used.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskDropdown({
    required String label,
    required String description,
    required String? currentId,
    required List<LlmConfig> availableConfigs,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.glassSurface.withValues(alpha: 0.12),
            AppColors.glassSurface.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: currentId,
            decoration: InputDecoration(
              hintText: 'Use default LLM',
              filled: true,
              fillColor: AppColors.glassSurface.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            dropdownColor: AppColors.glassSurface,
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  'Use default LLM',
                  style: TextStyle(color: AppColors.onSurface),
                ),
              ),
              ...availableConfigs.map((LlmConfig config) {
                return DropdownMenuItem<String>(
                  value: config.id,
                  child: Text(
                    config.label,
                    style: const TextStyle(color: AppColors.onSurface),
                  ),
                );
              }),
            ],
            onChanged: onChanged,
            iconEnabledColor: AppColors.primary,
            style: const TextStyle(color: AppColors.onSurface),
          ),
        ],
      ),
    );
  }

  void _updateTaskConfig(BuildContext context, TaskLlmConfig config) {
    context.read<SettingsCubit>().setTaskLlmConfig(config);
  }
}
