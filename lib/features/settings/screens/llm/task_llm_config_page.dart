import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/res/app_colors.dart';
import '../../../../core/models/task_llm_config.dart';
import '../../../../core/models/llm_config.dart';
import '../../bloc/settings_cubit.dart';
import '../../bloc/settings_state.dart';

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
              // Background gradient layers
              const _BackgroundLayers(),
              // Content
              SafeArea(
                child: Column(
                  children: <Widget>[
                    _CustomAppBar(fadeAnimation: _fadeAnimation),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: <Widget>[
                          const SizedBox(height: 8),
                          _buildSectionTitle(
                            'Task Configuration',
                            _fadeAnimation,
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
                                      _buildTaskDropdown(
                                        label: 'Assistant',
                                        description:
                                            'LLM used for main chat responses',
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
                                      _buildTaskDropdown(
                                        label: 'Title Generation',
                                        description:
                                            'LLM used to generate chat titles',
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
                                      _buildTaskDropdown(
                                        label: 'Function Calling',
                                        description:
                                            'LLM used for tool/function detection',
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
                                      _buildInfoCard(_fadeAnimation),
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

  Widget _buildSectionTitle(String title, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - animation.value)),
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.onSurface.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: animation.value,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.secondary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'If no LLM is selected for a task, the default assistant LLM will be used.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurface.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskDropdown({
    required String label,
    required String description,
    required IconData icon,
    required String? currentId,
    required List<LlmConfig> availableConfigs,
    required ValueChanged<String?> onChanged,
    required int delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + delay),
      curve: Curves.easeOut,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - value)),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppColors.glassSurface.withValues(alpha: 0.16),
                    AppColors.glassSurface.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.glassBorder.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.surface.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              AppColors.primary.withValues(alpha: 0.15),
                              AppColors.secondary.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              label,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                    letterSpacing: -0.3,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              description,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                                    fontSize: 11,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStyledDropdown(
                    currentValue: currentId,
                    availableConfigs: availableConfigs,
                    onChanged: onChanged,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStyledDropdown({
    required String? currentValue,
    required List<LlmConfig> availableConfigs,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: currentValue,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.primary,
            size: 24,
          ),
          items: <DropdownMenuItem<String?>>[
            DropdownMenuItem<String?>(
              value: null,
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.autorenew_rounded,
                    size: 18,
                    color: AppColors.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Use default LLM',
                    style: TextStyle(
                      color: AppColors.onSurface.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            ...availableConfigs.map((LlmConfig config) {
              final bool isSelected = config.id == currentValue;
              return DropdownMenuItem<String>(
                value: config.id,
                child: Container(
                  decoration: isSelected
                      ? BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              AppColors.primary.withValues(alpha: 0.1),
                              AppColors.secondary.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  padding: isSelected
                      ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                      : null,
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          config.label,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.onSurface.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          onChanged: onChanged,
          selectedItemBuilder: (BuildContext context) {
            return <DropdownMenuItem<String?>>[
              DropdownMenuItem<String?>(
                value: null,
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.autorenew_rounded,
                      size: 18,
                      color: AppColors.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Use default LLM',
                      style: TextStyle(
                        color: AppColors.onSurface.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              ...availableConfigs.map((LlmConfig config) {
                return DropdownMenuItem<String>(
                  value: config.id,
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          config.label,
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ];
          },
        ),
      ),
    );
  }

  void _updateTaskConfig(BuildContext context, TaskLlmConfig config) {
    context.read<SettingsCubit>().setTaskLlmConfig(config);
  }
}

class _BackgroundLayers extends StatelessWidget {
  const _BackgroundLayers();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: <Widget>[
          // Base gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[AppColors.background, AppColors.surface],
                ),
              ),
            ),
          ),
          // Gradient mesh overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.2,
                  colors: <Color>[
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.secondary.withValues(alpha: 0.05),
                    AppColors.surface.withValues(alpha: 0.0),
                  ],
                  stops: const <double>[0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Noise texture overlay for depth
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    AppColors.surface.withValues(alpha: 0.4),
                    AppColors.surface.withValues(alpha: 0.2),
                    AppColors.surface.withValues(alpha: 0.4),
                  ],
                  stops: const <double>[0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomAppBar extends StatelessWidget {
  final Animation<double> fadeAnimation;

  const _CustomAppBar({required this.fadeAnimation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: fadeAnimation,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, -10 * (1 - fadeAnimation.value)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.glassSurface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.glassBorder.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: AppColors.onSurface,
                      onPressed: () => Navigator.of(context).pop(),
                      iconSize: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Task LLM Configuration',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 56), // Balance the back button
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
