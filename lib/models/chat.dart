import 'package:equatable/equatable.dart';

import 'bg_images.dart';
import 'chat_entry.dart';

class Chat extends Equatable {
  final String id;
  final List<ChatEntry> entries;
  final BgImages? bgImages;

  const Chat({
    required this.id,
    required this.entries,
    required this.bgImages,
  });

  Chat copyWith({
    String? id,
    List<ChatEntry>? entries,
    BgImages? bgImages,
  }) {
    return Chat(
      id: id ?? this.id,
      entries: entries ?? this.entries,
      bgImages: bgImages ?? this.bgImages,
    );
  }

  @override
  List<Object> get props => <Object>[id, entries];
}
