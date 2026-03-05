// ignore_for_file: avoid_dynamic_calls, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/sound_effects.dart';
import '../../../core/res/app_colors.dart';
import '../../../l10n/localization_manager.dart';
import '../../chat/bloc/chats_cubit.dart';
import '../../chat/domain/models/chat.dart';
import '../bloc/settings_cubit.dart';
import '../widgets/api_key_field.dart';
import '../widgets/persona_dropdown.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/sound_effects_toggle.dart';
import '../widgets/username_field.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  final TextEditingController _baseSystemPromptController =
      TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  bool _isSoundEffectsEnabled = true;
  ChatPersona _persona = ChatPersona.assistant;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final SettingsCubit settingsCubit = context.read<SettingsCubit>();
    await settingsCubit.loadSettings();

    // Load additional settings from ChatsCubit for sound effects
    _isSoundEffectsEnabled = context
        .read<ChatsCubit>()
        .state
        .soundEffectsEnabled;
    setState(() {});
  }

  void _onSaveButtonPressed() async {
    final SettingsCubit settingsCubit = context.read<SettingsCubit>();

    if (_baseSystemPromptController.text.isNotEmpty) {
      await settingsCubit.setSystemPrompt(_baseSystemPromptController.text);
    }
    if (_usernameController.text.isNotEmpty) {
      await settingsCubit.setUsername(_usernameController.text);
    }
    await settingsCubit.setPersona(_persona);
    context.read<ChatsCubit>().setSoundEffects(_isSoundEffectsEnabled);
    context.pop();
  }

  Widget _buildTaskLlmConfigTile(BuildContext context) {
    return InkWell(
      onTap: () => context.push("/settings/llm/task-llm"),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.glassSurface.withValues(alpha: 0.12),
              AppColors.glassSurface.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.glassBorder.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.psychology_outlined,
              color: AppColors.onSurface.withValues(alpha: 0.7),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    localized.taskLlmConfig,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configure different LLMs for assistant, title generation, and function calling',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.onSurface.withValues(alpha: 0.3),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final StringBuffer soundEffectsList = StringBuffer();
    for (final SoundEffects soundEffect in SoundEffects.values) {
      soundEffectsList.write("[$soundEffect], ");
    }
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppColors.background, AppColors.surface],
          ),
        ),
        child: Column(
          children: <Widget>[
            SafeArea(
              bottom: false,
              child: SettingsAppBar(onSave: _onSaveButtonPressed),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 16),
                      Text(
                        localized.settingsSubstring,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const ApiKeyField(),
                      const SizedBox(height: 16),
                      UsernameField(controller: _usernameController),
                      const SizedBox(height: 16),
                      PersonaDropdown(
                        value: _persona,
                        onChanged: (ChatPersona newValue) {
                          _persona = newValue;
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                      SoundEffectsToggle(
                        value: _isSoundEffectsEnabled,
                        onChanged: (bool value) {
                          setState(() {
                            _isSoundEffectsEnabled = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTaskLlmConfigTile(context),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
