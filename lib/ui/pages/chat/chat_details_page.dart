import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_parsed_text/flutter_parsed_text.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lottie/lottie.dart';

import '../../../logic/avatar/avatar_cubit.dart';
import '../../../logic/avatar/avatar_state.dart';
import '../../../logic/chat/chats_cubit.dart';
import '../../../models/avatar.dart';
import '../../../models/chat.dart';
import '../../../models/chat_entry.dart';
import '../../../models/sound_effects.dart';
import '../../../utils/app_utils.dart';
import '../../../utils/extensions.dart';
import '../../widgets/ai_text_input.dart';
import '../../widgets/app_icon_button.dart';
import 'image_full_screen.dart';

class ChatDetailsPage extends StatefulWidget {
  const ChatDetailsPage();

  @override
  State<ChatDetailsPage> createState() => _ChatDetailsPageState();
}

class _ChatDetailsPageState extends State<ChatDetailsPage> {
  bool _showEverything = false;
  @override
  Widget build(BuildContext context) {
    return BlocListener<AvatarCubit, AvatarState>(
      listenWhen: (AvatarState previous, AvatarState current) =>
          previous.avatarConfig != current.avatarConfig,
      listener: (BuildContext context, AvatarState state) {
        context.read<AvatarCubit>().onNewAvatarConfig(
              context.read<ChatsCubit>().state.openedChat.id,
              state.avatarConfig,
            );
      },
      child: BlocBuilder<AvatarCubit, AvatarState>(
        builder: (BuildContext context, AvatarState avatarState) {
          return BlocBuilder<ChatsCubit, ChatsState>(
            buildWhen: (ChatsState previous, ChatsState current) =>
                previous.status != current.status,
            builder: (BuildContext context, ChatsState state) {
              final Chat chat = state.openedChat;
              return Scaffold(
                body: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.3,
                        child: Image.asset(
                          state.openedChat.avatar.background.getPath(),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            child: _buildConversation(
                              context,
                              chat.entries.reversed.toList(),
                              state.status == ChatsStatus.typing,
                            ),
                          ),
                          const AiTextInput(
                            onlyText: true,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: SafeArea(
                        child: AppIconButton(
                          icon: Icons.arrow_back_ios_new_outlined,
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: SafeArea(
                        child: AppIconButton(
                          icon: _showEverything
                              ? Icons.visibility
                              : Icons.visibility_off,
                          onPressed: () {
                            setState(() {
                              _showEverything = !_showEverything;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildConversation(
    BuildContext contex,
    List<ChatEntry> chat,
    bool isTyping,
  ) =>
      ListView.builder(
        itemCount: chat.length,
        reverse: true,
        itemBuilder: (BuildContext context, int index) {
          return Column(
            children: <Widget>[
              if (index == chat.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      chat[index].timestamp.toLongLocalDateString(
                            language: context
                                .read<ChatsCubit>()
                                .state
                                .currentLanguage,
                          ),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (chat[index].entryType == EntryType.functionCalling)
                _functionCallingItem(chat[index].body)
              else
                _buildMessageItem(chat, index, isTyping),
            ],
          );
        },
      );

  Widget _buildMessageItem(List<ChatEntry> entries, int index, bool isTyping) {
    final bool isFromUser = entries[index].entryType == EntryType.user;
    String soundEffect = '';
    if (!isFromUser) {
      final dynamic json = jsonDecode(entries[index].body);
      soundEffect =
          (json as Map<String, dynamic>)['soundEffect'] as String? ?? '';
    }
    return Padding(
      padding: EdgeInsets.only(
        bottom: 8,
        left: isFromUser
            ? isTyping
                ? 0
                : 32
            : 0,
        right: isFromUser ? 0 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment:
                  isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: <Widget>[
                if (!isFromUser) _circleAvatar(),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: !isFromUser ? Colors.blue : Colors.pink[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: <Widget>[
                        ParsedText(
                          selectable: true,
                          text: _showEverything
                              ? entries[index].body
                              : entries[index]
                                  .getMessage(isFromUser: isFromUser),
                          style: TextStyle(
                            color: !isFromUser ? Colors.white : Colors.black,
                          ),
                        ),
                        if (soundEffect.isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              onTap: () async {
                                final SoundEffects? sound =
                                    soundEffect.getSoundEffectFromString();
                                if (sound == null) return;
                                final AudioPlayer player = AudioPlayer();
                                await player.setAsset(sound.getPath());
                                await player.play();
                                player.dispose();
                              },
                              child: const Icon(
                                Icons.volume_up_outlined,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (entries[index].attachedImage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<dynamic>(
                          builder: (BuildContext context) => ImageFullScreen(
                            imagePath: entries[index].attachedImage!,
                          ),
                        ),
                      );
                    },
                    child: Hero(
                      tag: entries[index].attachedImage!,
                      child: Image.file(
                        File(entries[index].attachedImage!),
                        fit: BoxFit.cover,
                        width: 100,
                        height: 100,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (index == 0 && isTyping)
            Row(
              children: <Widget>[
                _circleAvatar(),
                Lottie.asset(
                  AppUtils.fixAssetsPath('assets/lotties/typing.json'),
                  height: 60,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _circleAvatar() => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: CircleAvatar(
          backgroundColor: Colors.blue,
          foregroundImage:
              AssetImage(AppUtils.fixAssetsPath("assets/icon.png")),
        ),
      );

  Widget _functionCallingItem(String function) {
    final StringBuffer bf = StringBuffer();
    final List<dynamic> map = jsonDecode(function) as List<dynamic>;
    for (int i = 0; i < map.length; i++) {
      bf.write(
        '${(map[i] as Map<String, dynamic>)["name"]}(${(map[i] as Map<String, dynamic>)["parameters"]})${i == map.length - 1 ? '' : '\n'}',
      );
    }
    if (bf.isNotEmpty && bf.toString().endsWith('\n')) {}

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.black.withOpacity(0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                bf.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
