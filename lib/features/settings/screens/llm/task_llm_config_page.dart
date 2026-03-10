import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/models/task_llm_config.dart';
import '../../../../core/models/llm_config.dart';
import '../../presentation/bloc/settings_cubit.dart';
import '../../presentation/bloc/settings_state.dart';
import 'widgets/task_llm_background_layers.dart';
import 'widgets/task_llm_app_bar.dart';
import 'widgets/task_section_title.dart';
import 'widgets/task_info_card.dart';
import 'widgets/task_dropdown.dart';

/// Settings page for configuring task-specific LLM mappings
/// Features cosmic glassmorphism design with layered backgrounds and smooth animations
class TaskLlmConfigPage extends StatefulWidget {
  const TaskLlmConfigPage({super.key});

  @override
  State<TaskLlmConfigPage> createState() => _TaskLlmConfigPageState();
}

class _TaskLlmConfigPageState extends State<TaskLlmConfigPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    context.read<SettingsCubit>().loadSettings();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
          body: Stack(
            children: <Widget>[
              const TaskLlmBackgroundLayers(),
              SafeArea(
                child: Column(
                  children: <Widget>[
                    TaskLlmAppBar(fadeAnimation: _fadeAnimation),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: <Widget>[
                          const SizedBox(height: 8),
                          TaskSectionTitle(
                            title: AppLocalizations.of(context).taskLlmConfig,
                            animation: _fadeAnimation,
                          ),
                          const SizedBox(height: 20),
                          AnimatedBuilder(
                            animation: _fadeAnimation,
                            builder: (BuildContext context, Widget? child) {
                              return Opacity(
                                opacity: _fadeAnimation.value,
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    20 * (1 - _fadeAnimation.value),
                                  ),
                                  child: Column(
                                    children: <Widget>[
                                      TaskDropdown(
                                        label: AppLocalizations.of(
                                          context,
                                        ).assistantTask,
                                        description: AppLocalizations.of(
                                          context,
                                        ).taskLlmDescription,
                                        icon: Icons.chat_bubble_outline,
                                        currentId: taskConfig.assistantLlmId,
                                        availableConfigs: availableConfigs,
                                        onChanged: (String? id) =>
                                            _updateTaskConfig(
                                              context,
                                              taskConfig.copyWith(
                                                assistantLlmId: id,
                                              ),
                                            ),
                                        delay: 0,
                                      ),
                                      const SizedBox(height: 16),
                                      TaskDropdown(
                                        label: AppLocalizations.of(
                                          context,
                                        ).titleTask,
                                        description: AppLocalizations.of(
                                          context,
                                        ).titleLlmDescription,
                                        icon: Icons.title_outlined,
                                        currentId:
                                            taskConfig.titleGenerationLlmId,
                                        availableConfigs: availableConfigs,
                                        onChanged: (String? id) =>
                                            _updateTaskConfig(
                                              context,
                                              taskConfig.copyWith(
                                                titleGenerationLlmId: id,
                                              ),
                                            ),
                                        delay: 100,
                                      ),
                                      const SizedBox(height: 16),
                                      TaskDropdown(
                                        label: AppLocalizations.of(
                                          context,
                                        ).functionCallingTask,
                                        description: AppLocalizations.of(
                                          context,
                                        ).functionCallingLlmDescription,
                                        icon: Icons.extension_outlined,
                                        currentId:
                                            taskConfig.functionCallingLlmId,
                                        availableConfigs: availableConfigs,
                                        onChanged: (String? id) =>
                                            _updateTaskConfig(
                                              context,
                                              taskConfig.copyWith(
                                                functionCallingLlmId: id,
                                              ),
                                            ),
                                        delay: 200,
                                      ),
                                      const SizedBox(height: 28),
                                      TaskInfoCard(animation: _fadeAnimation),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateTaskConfig(BuildContext context, TaskLlmConfig config) {
    context.read<SettingsCubit>().setTaskLlmConfig(config);
  }
}
