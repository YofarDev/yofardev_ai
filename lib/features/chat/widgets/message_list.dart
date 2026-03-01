import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../features/chat/bloc/chats_cubit.dart';
import '../../../core/models/chat.dart';
import '../../../core/models/chat_entry.dart';
import 'function_calling_widget.dart';
import '../../../core/utils/extensions.dart';
import 'message_bubble.dart';

/// Message list with reversed ListView
/// Extracted from chat_details_page.dart (326 → 80 lines)
class MessageList extends StatelessWidget {
  final List<ChatEntry> entries;
  final ChatPersona persona;
  final bool isTyping;
  final bool showEverything;
  final void Function(String)? onImageTap;

  const MessageList({
    super.key,
    required this.entries,
    required this.persona,
    required this.isTyping,
    required this.showEverything,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: entries.length,
      reverse: true,
      itemBuilder: (BuildContext context, int index) {
        return Column(
          children: <Widget>[
            if (index == entries.length - 1 && showEverything)
              Text(
                "Persona : ${persona.name}",
                style: const TextStyle(fontSize: 10),
              ),
            if (index == entries.length - 1)
              _DateHeader(entryIndex: index, entries: entries),
            if (entries[index].entryType == EntryType.functionCalling)
              FunctionCallingWidget(functionCallingText: entries[index].body)
            else
              MessageBubble(
                entry: entries[index],
                isTyping: index == 0 && isTyping,
                showEverything: showEverything,
                onImageTap: onImageTap,
              ),
          ],
        );
      },
    );
  }
}

class _DateHeader extends StatelessWidget {
  final int entryIndex;
  final List<ChatEntry> entries;

  const _DateHeader({required this.entryIndex, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          entries[entryIndex].timestamp.toLongLocalDateString(
            language: context.read<ChatsCubit>().state.currentLanguage,
          ),
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
