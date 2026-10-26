import 'package:flutter/material.dart';
import '../../../core/widgets/typing_indicator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/chat.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/models/chat_entry.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/chat_message_item.dart';
import 'function_calling_widget.dart';
import '../../settings/settings.dart';

class ChatConversationList extends StatelessWidget {
  final ChatPersona persona;
  final List<ChatEntry> entries;
  final bool isTyping;
  final bool showEverything;
  final bool isStreaming;
  final String Function(String, bool) limitParameterSize;

  const ChatConversationList({
    super.key,
    required this.persona,
    required this.entries,
    required this.isTyping,
    required this.showEverything,
    required this.isStreaming,
    required this.limitParameterSize,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: entries.length + (isTyping ? 1 : 0),
      reverse: true,
      itemBuilder: (BuildContext context, int index) {
        // Show typing indicator at the top (index 0 in reversed list)
        if (index == 0 && isTyping) {
          return const _TypingIndicator();
        }

        // Adjust index for typing indicator offset
        final int adjustedIndex = isTyping ? index - 1 : index;

        return Column(
          children: <Widget>[
            if (adjustedIndex == entries.length - 1 && showEverything)
              Text(
                'Persona : ${persona.name}',
                style: const TextStyle(fontSize: 10),
              ),
            if (adjustedIndex == entries.length - 1)
              _DateHeader(timestamp: entries[adjustedIndex].timestamp),
            if (entries[adjustedIndex].entryType == EntryType.functionCalling)
              FunctionCallingWidget(
                functionCallingText: entries[adjustedIndex].body,
                showEverything: showEverything,
              )
            else
              ChatMessageItem(
                entries: entries,
                index: adjustedIndex,
                isTyping: false, // Already handled at list level
                showEverything: showEverything,
                isStreaming: isStreaming,
                limitParameterSize: limitParameterSize,
              ),
          ],
        );
      },
    );
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime timestamp;

  const _DateHeader({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                context.tokens.glassSurface.withValues(alpha: 0.15),
                context.tokens.glassSurface.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: context.tokens.glassBorder.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Text(
            timestamp.toLongLocalDateString(
              language: context.read<SettingsCubit>().state.currentLanguage,
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 40, top: 8),
      child: Row(
        children: <Widget>[
          const ChatAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  context.tokens.glassSurface.withValues(alpha: 0.15),
                  context.tokens.glassSurface.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.tokens.glassBorder.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: const TypingIndicator(),
          ),
        ],
      ),
    );
  }
}
