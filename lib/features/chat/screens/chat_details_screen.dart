import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nested/nested.dart';
import 'package:path_provider/path_provider.dart';

import '../../avatar/presentation/bloc/avatar_cubit.dart';
import '../../avatar/presentation/bloc/avatar_state.dart';
import '../presentation/bloc/chats_cubit.dart';
import '../presentation/bloc/chats_state.dart';
import '../../../core/utils/logger.dart';

import '../../../core/widgets/app_icon_button.dart';
import '../domain/models/chat.dart';
import '../domain/models/chat_entry.dart';
import '../widgets/ai_text_input/ai_text_input.dart';
import '../widgets/chat_conversation_list.dart';
import '../widgets/chat_details_actions.dart';
import '../widgets/chat_details_background.dart';
import '../widgets/floating_stop_button.dart';
import '../presentation/bloc/chat_message_cubit.dart';
import '../presentation/bloc/chat_message_state.dart';

class ChatDetailsPage extends StatefulWidget {
  const ChatDetailsPage({super.key});

  @override
  State<ChatDetailsPage> createState() => _ChatDetailsPageState();
}

class _ChatDetailsPageState extends State<ChatDetailsPage> {
  bool _showEverything = false;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: <SingleChildWidget>[
        BlocListener<AvatarCubit, AvatarState>(
          listenWhen: (AvatarState previous, AvatarState current) =>
              previous.avatarConfig != current.avatarConfig,
          listener: (BuildContext context, AvatarState state) {
            context.read<AvatarCubit>().onNewAvatarConfig(
              context.read<ChatsCubit>().state.openedChat.id,
              state.avatarConfig,
            );
          },
        ),
        BlocListener<ChatMessageCubit, ChatMessageState>(
          listenWhen: (ChatMessageState previous, ChatMessageState current) =>
              previous.status != current.status,
          listener: (BuildContext context, ChatMessageState state) {
            if (state.status == ChatMessageStatus.interrupted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Response interrupted'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ],
      child: BlocBuilder<ChatsCubit, ChatsState>(
        builder: (BuildContext context, ChatsState state) {
          final Chat chat = state.openedChat;
          return Scaffold(
            body: Stack(
              children: <Widget>[
                const ChatDetailsBackground(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: ChatConversationList(
                          persona: chat.persona,
                          entries: chat.entries.reversed.toList(),
                          isTyping: state.status == ChatsStatus.typing,
                          isStreaming: state.status == ChatsStatus.streaming,
                          showEverything: _showEverything,
                          limitParameterSize: _limitParamaterSize,
                        ),
                      ),
                      const AiTextInput(onlyText: true),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                const _TopLeftBackButton(),
                BlocBuilder<ChatsCubit, ChatsState>(
                  builder: (BuildContext context, ChatsState actionsState) {
                    return ChatDetailsActions(
                      showEverything: _showEverything,
                      onToggleVisibility: () {
                        setState(() {
                          _showEverything = !_showEverything;
                        });
                      },
                      onDownload: () => _downloadConversation(context),
                      isFunctionCallingEnabled: actionsState.functionCallingEnabled,
                      onFunctionCallingToggle: () =>
                          context.read<ChatsCubit>().toggleFunctionCalling(),
                    );
                  },
                ),
                const FloatingStopButton(),
              ],
            ),
          );
        },
      ),
    );
  }

  String _limitParamaterSize(String body, bool isFromUser) {
    if (!isFromUser) return body;
    try {
      const int limit = 2000;
      if (body.length > limit) {
        final String reduced = '${body.substring(0, limit)} [...]';
        String userMessage = '';
        final int startIndex = body.indexOf("'''");
        final int endIndex = body.lastIndexOf("'''");
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          userMessage = body.substring(startIndex + 3, endIndex);
        } else {
          return body;
        }
        return "$reduced\nUser's message : \n'''$userMessage'''";
      }
      return body;
    } catch (e) {
      AppLogger.error(
        'Error limiting parameter size',
        tag: 'ChatDetails',
        error: e,
      );
      return body;
    }
  }

  Future<void> _downloadConversation(BuildContext context) async {
    try {
      final Chat chat = context.read<ChatsCubit>().state.openedChat;

      final Map<String, dynamic> conversationData = <String, dynamic>{
        'metadata': <String, dynamic>{
          'chat_id': chat.id,
          'persona': chat.persona.name,
          'language': chat.language,
          'system_prompt': chat.systemPrompt,
          'avatar_config': chat.avatar.toMap(),
          'created_at': chat.entries.isNotEmpty
              ? chat.entries.first.timestamp.toIso8601String()
              : DateTime.now().toIso8601String(),
          'exported_at': DateTime.now().toIso8601String(),
        },
        'entries': chat.entries
            .map(
              (ChatEntry entry) => <String, dynamic>{
                'id': entry.id,
                'type': entry.entryType.name,
                'body': entry.body,
                'timestamp': entry.timestamp.toIso8601String(),
                'attached_image': entry.attachedImage,
              },
            )
            .toList(),
      };

      final String jsonString = const JsonEncoder.withIndent(
        '  ',
      ).convert(conversationData);
      final DateTime now = DateTime.now();
      final String fileName =
          'chat_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.json';

      Directory? downloadsDir;
      if (Platform.isMacOS || Platform.isLinux) {
        downloadsDir = Directory('${Platform.environment['HOME']}/Downloads');
      } else if (Platform.isWindows) {
        downloadsDir = Directory(
          '${Platform.environment['USERPROFILE']}\\Downloads',
        );
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      final String filePath =
          '${downloadsDir.path}${Platform.pathSeparator}$fileName';
      final File file = File(filePath);
      await file.writeAsString(jsonString);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversation downloaded: $fileName'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      AppLogger.error(
        'Error downloading conversation',
        tag: 'ChatDetails',
        error: e,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

class _TopLeftBackButton extends StatelessWidget {
  const _TopLeftBackButton();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 8,
      top: 8,
      child: SafeArea(
        child: AppIconButton(
          icon: Icons.arrow_back_ios_new_outlined,
          onPressed: () {
            context.pop();
          },
        ),
      ),
    );
  }
}
