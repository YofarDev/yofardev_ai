import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yofardev_ai/logic/chat/chats_cubit.dart';
import 'package:yofardev_ai/models/chat_entry.dart';

/// Text input field for chat messages
/// Extracted from ai_text_input.dart (358 → 80 lines)
class TextInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  const TextInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatsCubit, ChatsState>(
      builder: (context, state) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Type a message...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.send),
              onPressed: onSend,
            ),
          ),
        );
      },
    );
  }
}
