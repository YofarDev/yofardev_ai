import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../presentation/bloc/chats_cubit.dart';
import '../../../core/models/chat.dart';
import '../../../core/res/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../domain/models/chat_entry.dart';
import '../widgets/chat_message_item.dart';
import 'function_calling_widget.dart';

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
      itemCount: entries.length,
      reverse: true,
      itemBuilder: (BuildContext context, int index) {
        return Column(
          children: <Widget>[
            if (index == entries.length - 1 && showEverything)
              Text(
                'Persona : ${persona.name}',
                style: const TextStyle(fontSize: 10),
              ),
            if (index == entries.length - 1)
              _DateHeader(timestamp: entries[index].timestamp),
            if (entries[index].entryType == EntryType.functionCalling)
              FunctionCallingWidget(functionCallingText: entries[index].body)
            else
              ChatMessageItem(
                entries: entries,
                index: index,
                isTyping: isTyping,
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
                AppColors.glassSurface.withValues(alpha: 0.15),
                AppColors.glassSurface.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.glassBorder.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Text(
            timestamp.toLongLocalDateString(
              language: context.read<ChatsCubit>().state.currentLanguage,
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
