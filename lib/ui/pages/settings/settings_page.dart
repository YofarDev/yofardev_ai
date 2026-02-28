// ignore_for_file: avoid_dynamic_calls, use_build_context_synchronously

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/chat/bloc/chats_cubit.dart';
import '../../../l10n/localization_manager.dart';
import '../../../models/chat.dart';
import '../../../models/sound_effects.dart';
import '../../../res/app_colors.dart';
import '../../../services/settings_service.dart';
import '../../widgets/constrained_width.dart';
import '../../widgets/settings/glassmorphic_switch.dart';
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
              _buildAppBar(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      localized.settingsSubstring,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildApiKeyField(),
                    const SizedBox(height: 16),
                    _buildUsernameField(),
                    const SizedBox(height: 16),
                    _dropdownChatPersonas(),
                    const SizedBox(height: 16),
                    _buildSoundEffectsCheckbox(),
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

  Widget _buildAppBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: <Color>[
          AppColors.surface.withValues(alpha: 0.9),
          AppColors.surface.withValues(alpha: 0.7),
        ],
      ),
      border: Border(
        bottom: BorderSide(
          color: AppColors.glassBorder.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          localized.settings,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                AppColors.success.withValues(alpha: 0.2),
                AppColors.success.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: IconButton(
            icon: const Icon(Icons.save),
            onPressed: _onSaveButtonPressed,
            tooltip: 'Save',
          ),
        ),
      ],
    ),
  );

  Widget _dropdownChatPersonas() => Container(
    padding: const EdgeInsets.all(8.0),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey),
      borderRadius: BorderRadius.circular(8.0),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(localized.personaAssistant, style: const TextStyle(fontSize: 20)),
        DropdownButton<String>(
          value: _persona.name,
          items: ChatPersona.values
              .map<String>((ChatPersona value) => value.name)
              .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(value.toUpperCase()),
                  ),
                );
              })
              .toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              _persona = ChatPersona.values.byName(newValue);
              SettingsService().setPersona(_persona);
              setState(() {});
            }
          },
        ),
      ],
    ),
  );

  Widget _buildApiKeyField() => ElevatedButton(
    child: const Text('Api Picker'),
    onPressed: () {
      Navigator.of(context).push(
        MaterialPageRoute<dynamic>(
          builder: (BuildContext context) =>
              const ConstrainedWidth(child: LlmSelectionPage()),
        ),
      );
    },
  );

  Widget _buildUsernameField() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: <Color>[
          AppColors.glassSurface.withValues(alpha: 0.12),
          AppColors.glassSurface.withValues(alpha: 0.06),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: AppColors.glassBorder.withValues(alpha: 0.4),
        width: 1.5,
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: TextFormField(
          controller: _usernameController,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurface),
          decoration: InputDecoration(
            hintText: localized.username,
            hintStyle: TextStyle(
              color: AppColors.onSurface.withValues(alpha: 0.5),
            ),
            prefixIcon: Icon(
              Icons.person_outline,
              color: AppColors.onSurface.withValues(alpha: 0.7),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildSoundEffectsCheckbox() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: <Color>[
          AppColors.glassSurface.withValues(alpha: 0.12),
          AppColors.glassSurface.withValues(alpha: 0.06),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: AppColors.glassBorder.withValues(alpha: 0.4),
        width: 1.5,
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    AppColors.warning.withValues(alpha: 0.2),
                    AppColors.warning.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.volume_up_outlined,
                color: AppColors.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              localized.enableSoundEffects,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.onSurface),
            ),
          ],
        ),
        GlassmorphicSwitch(
          value: _isSoundEffectsEnabled,
          onChanged: (bool value) {
            setState(() {
              _isSoundEffectsEnabled = value;
            });
          },
        ),
      ],
    ),
  );
}
