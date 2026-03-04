// ignore_for_file: avoid_dynamic_calls, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/models/sound_effects.dart';
import '../../../core/res/app_colors.dart';
import '../../../l10n/localization_manager.dart';
import '../../chat/bloc/chats_cubit.dart';
import '../../chat/domain/models/chat.dart';
import '../domain/repositories/settings_repository.dart';
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
    final SettingsRepository settingsRepo = getIt<SettingsRepository>();

    final Either<Exception, String> promptResult = await settingsRepo
        .getSystemPrompt();
    promptResult.fold(
      (Exception error) => null,
      (String prompt) => _baseSystemPromptController.text = prompt,
    );

    final Either<Exception, String?> usernameResult = await settingsRepo
        .getUsername();
    usernameResult.fold(
      (Exception error) => null,
      (String? username) => _usernameController.text = username ?? '',
    );

    final Either<Exception, ChatPersona> personaResult = await settingsRepo
        .getPersona();
    personaResult.fold(
      (Exception error) => _persona = ChatPersona.assistant,
      (ChatPersona persona) => _persona = persona,
    );

    _isSoundEffectsEnabled = context
        .read<ChatsCubit>()
        .state
        .soundEffectsEnabled;
    setState(() {});
  }

  void _onSaveButtonPressed() async {
    final SettingsRepository settingsRepo = getIt<SettingsRepository>();

    if (_baseSystemPromptController.text.isNotEmpty) {
      await settingsRepo.setSystemPrompt(_baseSystemPromptController.text);
    }
    if (_usernameController.text.isNotEmpty) {
      await settingsRepo.setUsername(_usernameController.text);
    }
    await settingsRepo.setPersona(_persona);
    context.read<ChatsCubit>().setSoundEffects(_isSoundEffectsEnabled);
    context.pop();
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
