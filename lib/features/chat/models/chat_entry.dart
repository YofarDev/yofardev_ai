import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_entry.freezed.dart';
part 'chat_entry.g.dart';

/// Freezed ChatEntry model with union types
/// Replaces manual implementation with immutable, type-safe model
@freezed
class ChatEntry with _$ChatEntry {
  const factory ChatEntry.text({
    required String id,
    required String content,
    required String role,
    DateTime? timestamp,
  }) = ChatEntryText;

  const factory ChatEntry.image({
    required String id,
    required String imageUrl,
    required String role,
    DateTime? timestamp,
  }) = ChatEntryImage;

  const factory ChatEntry.toolCall({
    required String id,
    required String toolName,
    required Map<String, dynamic> arguments,
  }) = ChatEntryToolCall;

  factory ChatEntry.fromJson(Map<String, dynamic> json) =>
      _$ChatEntryFromJson(json);
}
