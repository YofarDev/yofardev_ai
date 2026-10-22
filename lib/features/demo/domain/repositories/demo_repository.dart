import '../../../../core/models/avatar_scene.dart';
import '../../../../core/models/result.dart';

/// Repository for demo-related operations.
///
/// This interface abstracts demo operations to remove direct
/// dependencies on Cubits and BuildContext from DemoService.
abstract class DemoRepository {
  /// Sets the avatar background for a specific chat.
  Future<Result<void>> setAvatarBackground(
    String chatId,
    AvatarScene background,
  );

  /// Gets the current chat ID.
  Future<Result<String>> getCurrentChatId();

  /// Updates the current chat for demo purposes.
  Future<Result<void>> updateChatForDemo(String chatId);
}
