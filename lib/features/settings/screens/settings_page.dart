// ignore_for_file: avoid_dynamic_calls, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/localization_manager.dart';
import '../../../logic/chat/chats_cubit.dart';
import '../../../models/chat.dart';
import '../../../models/voice.dart';
import '../../../utils/platform_utils.dart';
import '../bloc/settings_cubit.dart';
import '../bloc/settings_state.dart';
import '../widgets/api_picker_button.dart';
import '../widgets/persona_dropdown.dart';
import '../widgets/sound_effects_toggle.dart';
import '../widgets/username_field.dart';
import '../widgets/voice_selector.dart';

/// Main settings page with BLoC pattern
///
/// Uses SettingsCubit for state management and BlocListener
/// for navigation (avoiding anti-pattern of navigation in build).
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    // Load settings when page initializes
    context.read<SettingsCubit>().loadSettings();

    // Load voices for current language
    final String currentLanguage =
        context.read<ChatsCubit>().state.currentLanguage;
    context.read<SettingsCubit>().loadVoices(currentLanguage);
  }

  void _onSaveButtonPressed() {
    context.read<SettingsCubit>().saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<SettingsCubit, SettingsState>(
        listener: (BuildContext context, SettingsState state) {
          // Handle navigation based on state changes
          if (state is SettingsSaved) {
            Navigator.of(context).pop();
          } else if (state is SettingsError) {
            // Show error snackbar
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (BuildContext context, SettingsState state) {
            if (state is SettingsLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is SettingsLoaded) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _buildAppBar(context),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            localized.settingsSubstring,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const ApiPickerButton(),
                          const SizedBox(height: 16),
                          UsernameField(
                            controller: TextEditingController(
                              text: state.username,
                            )
                              ..selection = TextSelection.fromPosition(
                                TextPosition(offset: state.username.length),
                              ),
                          ),
                          const SizedBox(height: 16),
                          PersonaDropdown(
                            currentValue: state.persona,
                            onChanged: (ChatPersona persona) {
                              context
                                  .read<SettingsCubit>()
                                  .updatePersona(persona);
                            },
                          ),
                          const SizedBox(height: 16),
                          SoundEffectsToggle(
                            isEnabled: state.soundEffectsEnabled,
                            onChanged: (bool enabled) {
                              context
                                  .read<SettingsCubit>()
                                  .updateSoundEffects(enabled);
                            },
                          ),
                          const SizedBox(height: 16),
                          if (PlatformUtils.checkPlatform() != 'Web')
                            VoiceSelector(
                              selectedVoice: state.selectedVoice,
                              availableVoices: state.availableVoices,
                              currentLanguage: context
                                  .read<ChatsCubit>()
                                  .state
                                  .currentLanguage,
                              onVoiceChanged: (Voice voice) {
                                final String language = context
                                    .read<ChatsCubit>()
                                    .state
                                    .currentLanguage;
                                context
                                    .read<SettingsCubit>()
                                    .updateVoice(voice, language);
                              },
                            ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Fallback for initial state
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(localized.settings),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.save),
          onPressed: _onSaveButtonPressed,
        ),
      ],
    );
  }
}
