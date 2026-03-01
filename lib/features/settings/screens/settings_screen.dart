// ignore_for_file: avoid_dynamic_calls, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/chat.dart';
import '../../../core/models/sound_effects.dart';
import '../../../core/res/app_colors.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/widgets/constrained_width.dart';
import '../../../l10n/localization_manager.dart';
import '../../chat/bloc/chats_cubit.dart';
import '../widgets/persona_dropdown.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/sound_effects_toggle.dart';
import '../widgets/username_field.dart';
import 'llm/llm_selection_page.dart';

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
    _baseSystemPromptController.text = await SettingsService()
        .getBaseSystemPrompt();
    _usernameController.text = await SettingsService().getUsername() ?? '';
    _persona = await SettingsService().getPersona();
    _isSoundEffectsEnabled = context
        .read<ChatsCubit>()
        .state
        .soundEffectsEnabled;
    setState(() {});
  }

  void _onSaveButtonPressed() async {
    if (_baseSystemPromptController.text.isNotEmpty) {
      await SettingsService().setBaseSystemPrompt(
        _baseSystemPromptController.text,
      );
    }
    if (_usernameController.text.isNotEmpty) {
      await SettingsService().setUsername(_usernameController.text);
    }
    context.read<ChatsCubit>().setSoundEffects(_isSoundEffectsEnabled);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final StringBuffer soundEffectsList = StringBuffer();
    for (final SoundEffects soundEffect in SoundEffects.values) {
      soundEffectsList.write("[$soundEffect], ");
    }
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppColors.background, AppColors.surface],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SettingsAppBar(onSave: _onSaveButtonPressed),
              Padding(
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
                    _buildApiKeyField(),
                    const SizedBox(height: 16),
                    UsernameField(controller: _usernameController),
                    const SizedBox(height: 16),
                    PersonaDropdown(
                      value: _persona,
                      onChanged: (ChatPersona newValue) {
                        _persona = newValue;
                        SettingsService().setPersona(_persona);
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApiKeyField() => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: <Color>[
          AppColors.primary.withValues(alpha: 0.15),
          AppColors.primary.withValues(alpha: 0.08),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: 0.4),
        width: 1.5,
      ),
    ),
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: const Text('API Picker'),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<dynamic>(
            builder: (BuildContext context) =>
                const ConstrainedWidth(child: LlmSelectionPage()),
          ),
        );
      },
    ),
  );
}
