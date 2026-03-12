import 'package:uuid/uuid.dart';

import '../../../../core/models/avatar_config.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/models/chat_entry.dart';
import '../../../../core/repositories/settings_repository.dart';

/// Service responsible for creating chat entries
///
/// This service encapsulates the logic for creating properly formatted
/// chat entries, separating it from the UI layer.
class ChatEntryService {
  const ChatEntryService(this._settingsRepository);

  final SettingsRepository _settingsRepository;

  /// Creates a user entry with the given prompt and optional attached image
  ///
  /// The entry includes:
  /// - Current date formatted in the user's language
  /// - Current avatar configuration
  /// - The user's message wrapped in triple quotes
  Future<ChatEntry> createUserEntry({
    required String prompt,
    required Avatar avatar,
    String? attachedImage,
  }) async {
    final String languageCode = (await _settingsRepository.getLanguage()).fold(
      (Exception error) => 'fr',
      (String? language) => language ?? 'fr',
    );
    final String wrappedUserMessage =
        "Date : ${DateTime.now().toLongLocalDateString(language: languageCode)}\nAvatar Config :\n{\n$avatar\n}\nUser : \n'''$prompt'''";

    return ChatEntry(
      id: const Uuid().v4(),
      entryType: EntryType.user,
      body: wrappedUserMessage,
      timestamp: DateTime.now(),
      attachedImage: attachedImage,
    );
  }
}
