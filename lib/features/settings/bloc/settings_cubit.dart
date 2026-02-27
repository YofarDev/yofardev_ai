import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../models/chat.dart';
import '../../../models/voice.dart';
import '../../../services/settings_service.dart';
import '../../../utils/platform_utils.dart';
import 'settings_state.dart';

/// Cubit for managing application settings
///
/// Handles:
/// - User settings (username, persona)
/// - Sound settings (effects enabled, TTS voice)
/// - System prompt settings
class SettingsCubit extends Cubit<SettingsState> {
  final SettingsService _settingsService;

  SettingsCubit({
    required SettingsService settingsService,
  })  : _settingsService = settingsService,
        super(const SettingsInitial());

  /// Load all settings from persistent storage
  Future<void> loadSettings() async {
    try {
      emit(const SettingsLoading());

      // Load basic settings
      final String username = await _settingsService.getUsername() ?? '';
      final ChatPersona persona = await _settingsService.getPersona();
      final String baseSystemPrompt =
          await _settingsService.getBaseSystemPrompt();

      // Note: soundEffectsEnabled is managed by ChatsCubit
      // We'll need to pass this in or access it differently
      final bool soundEffectsEnabled =
          await _settingsService.getSoundEffects();

      emit(SettingsLoaded(
        username: username,
        persona: persona,
        soundEffectsEnabled: soundEffectsEnabled,
        baseSystemPrompt: baseSystemPrompt,
      ));
    } catch (e) {
      emit(SettingsError('Failed to load settings: $e'));
    }
  }

  /// Load available TTS voices for the current platform
  Future<void> loadVoices(String currentLanguage) async {
    final SettingsState currentState = state;
    if (currentState is! SettingsLoaded) return;

    try {
      emit(currentState.copyWith(isLoadingVoices: true));

      if (PlatformUtils.checkPlatform() == 'Web') {
        emit(currentState.copyWith(isLoadingVoices: false));
        return;
      }

      final FlutterTts flutterTts = FlutterTts();
      final List<dynamic> voices = await flutterTts.getVoices as List<dynamic>;
      final List<Voice> filteredVoices = <Voice>[];

      for (final dynamic voice in voices) {
        // ignore: avoid_dynamic_calls
        if (PlatformUtils.checkPlatform() == 'iOS' &&
            (voice['gender'] != 'male')) {
          continue;
        }

        // ignore: avoid_dynamic_calls
        // Filter by language
        if ((voice['locale'] as String).startsWith(currentLanguage)) {
          filteredVoices.add(
            Voice(
              // ignore: avoid_dynamic_calls
              name: voice['name'] as String,
              // ignore: avoid_dynamic_calls
              locale: voice['locale'] as String,
            ),
          );
        }
      }

      // Sort by locale
      filteredVoices.sort((Voice a, Voice b) => a.locale.compareTo(b.locale));

      // Load selected voice
      final String voiceName =
          await _settingsService.getTtsVoice(currentLanguage);
      Voice? selectedVoice;
      try {
        selectedVoice =
            filteredVoices.firstWhere((Voice voice) => voice.name == voiceName);
      } catch (_) {
        selectedVoice = filteredVoices.isNotEmpty ? filteredVoices.first : null;
      }

      emit(currentState.copyWith(
        availableVoices: filteredVoices,
        selectedVoice: selectedVoice,
        isLoadingVoices: false,
      ));
    } catch (e) {
      emit(currentState.copyWith(isLoadingVoices: false));
      emit(SettingsError('Failed to load voices: $e'));
    }
  }

  /// Update username setting
  Future<void> updateUsername(String username) async {
    final SettingsState currentState = state;
    if (currentState is! SettingsLoaded) return;

    try {
      await _settingsService.setUsername(username);
      emit(currentState.copyWith(username: username));
    } catch (e) {
      emit(SettingsError('Failed to update username: $e'));
    }
  }

  /// Update persona setting
  Future<void> updatePersona(ChatPersona persona) async {
    final SettingsState currentState = state;
    if (currentState is! SettingsLoaded) return;

    try {
      await _settingsService.setPersona(persona);
      emit(currentState.copyWith(persona: persona));
    } catch (e) {
      emit(SettingsError('Failed to update persona: $e'));
    }
  }

  /// Update sound effects enabled setting
  ///
  /// Note: This also updates ChatsCubit state
  Future<void> updateSoundEffects(bool enabled) async {
    final SettingsState currentState = state;
    if (currentState is! SettingsLoaded) return;

    try {
      await _settingsService.setSoundEffects(enabled);
      emit(currentState.copyWith(soundEffectsEnabled: enabled));
    } catch (e) {
      emit(SettingsError('Failed to update sound effects: $e'));
    }
  }

  /// Update selected TTS voice
  Future<void> updateVoice(Voice voice, String language) async {
    final SettingsState currentState = state;
    if (currentState is! SettingsLoaded) return;

    try {
      await _settingsService.setTtsVoice(voice.name, language);
      emit(currentState.copyWith(selectedVoice: voice));
    } catch (e) {
      emit(SettingsError('Failed to update voice: $e'));
    }
  }

  /// Update base system prompt
  Future<void> updateBaseSystemPrompt(String prompt) async {
    final SettingsState currentState = state;
    if (currentState is! SettingsLoaded) return;

    try {
      await _settingsService.setBaseSystemPrompt(prompt);
      emit(currentState.copyWith(baseSystemPrompt: prompt));
    } catch (e) {
      emit(SettingsError('Failed to update system prompt: $e'));
    }
  }

  /// Save all settings and navigate back
  Future<void> saveSettings() async {
    final SettingsState currentState = state;
    if (currentState is! SettingsLoaded) return;

    try {
      // Settings are already persisted as they're updated
      // This just emits success state for navigation
      emit(const SettingsSaved());
      // Return to loaded state after navigation
      emit(currentState);
    } catch (e) {
      emit(SettingsError('Failed to save settings: $e'));
    }
  }

  /// Reset to initial state
  void reset() {
    emit(const SettingsInitial());
  }
}
