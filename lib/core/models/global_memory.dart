import 'package:freezed_annotation/freezed_annotation.dart';

part 'global_memory.freezed.dart';

/// A single fact about the user remembered across all chats
@freezed
sealed class GlobalMemoryItem with _$GlobalMemoryItem {
  const GlobalMemoryItem._();

  const factory GlobalMemoryItem({
    required String id,
    required String text,
    required DateTime updatedAt,
  }) = _GlobalMemoryItem;

  factory GlobalMemoryItem.fromMap(Map<String, dynamic> map) {
    return GlobalMemoryItem(
      id: map['id'] as String? ?? '',
      text: map['text'] as String? ?? '',
      updatedAt: map['updatedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
                DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'text': text,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

/// The global memory store: facts about the user shared across all chats
@freezed
sealed class GlobalMemory with _$GlobalMemory {
  const GlobalMemory._();

  static const int maxItems = 30;
  static const int maxItemLength = 200;

  const factory GlobalMemory({
    @Default(<GlobalMemoryItem>[]) List<GlobalMemoryItem> items,
  }) = _GlobalMemory;

  factory GlobalMemory.empty() => const GlobalMemory();

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  List<String> get texts =>
      items.map((GlobalMemoryItem item) => item.text).toList();

  factory GlobalMemory.fromMap(Map<String, dynamic> map) {
    return GlobalMemory(
      items: List<GlobalMemoryItem>.from(
        (map['items'] as List<dynamic>? ?? <String>[]).map(
          (dynamic x) => GlobalMemoryItem.fromMap(x as Map<String, dynamic>),
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'items': items.map((GlobalMemoryItem x) => x.toMap()).toList(),
    };
  }
}
