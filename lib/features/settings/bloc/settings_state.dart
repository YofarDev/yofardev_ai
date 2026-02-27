import 'package:equatable/equatable.dart';

import '../../../models/chat.dart';
import '../../../models/voice.dart';

/// Abstract base class for all settings states
abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => <Object?>[];
}

/// Initial state when settings are loading
class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

/// Loading state while fetching settings
class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

/// Loaded state with all settings data
class SettingsLoaded extends SettingsState {
  final String username;
  final ChatPersona persona;
  final bool soundEffectsEnabled;
  final Voice? selectedVoice;
  final List<Voice> availableVoices;
  final String baseSystemPrompt;
  final bool isLoadingVoices;

  const SettingsLoaded({
    this.username = '',
    this.persona = ChatPersona.assistant,
    this.soundEffectsEnabled = true,
    this.selectedVoice,
    this.availableVoices = const <Voice>[],
    this.baseSystemPrompt = '',
    this.isLoadingVoices = false,
  });

  @override
  List<Object?> get props => <Object?>[
        username,
        persona,
        soundEffectsEnabled,
        selectedVoice,
        availableVoices,
        baseSystemPrompt,
        isLoadingVoices,
      ];

  /// Create a copy with modified fields
  SettingsLoaded copyWith({
    String? username,
    ChatPersona? persona,
    bool? soundEffectsEnabled,
    Voice? selectedVoice,
    List<Voice>? availableVoices,
    String? baseSystemPrompt,
    bool? isLoadingVoices,
  }) {
    return SettingsLoaded(
      username: username ?? this.username,
      persona: persona ?? this.persona,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      selectedVoice: selectedVoice ?? this.selectedVoice,
      availableVoices: availableVoices ?? this.availableVoices,
      baseSystemPrompt: baseSystemPrompt ?? this.baseSystemPrompt,
      isLoadingVoices: isLoadingVoices ?? this.isLoadingVoices,
    );
  }
}

/// Error state for settings operations
class SettingsError extends SettingsState {
  final String message;

  const SettingsError(this.message);

  @override
  List<Object?> get props => <Object?>[message];
}

/// Success state after saving settings
class SettingsSaved extends SettingsState {
  const SettingsSaved();
}
