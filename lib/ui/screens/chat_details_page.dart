import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_parsed_text/flutter_parsed_text.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lottie/lottie.dart';

import '../../logic/chat/chats_cubit.dart';
import '../../models/bg_images.dart';
import '../../models/chat.dart';
import '../../models/chat_entry.dart';
import '../../models/sound_effects.dart';
import '../../utils/extensions.dart';
import '../widgets/ai_text_input.dart';
import '../widgets/app_icon_button.dart';

class ChatDetailsPage extends StatelessWidget {
  const ChatDetailsPage();

  @override
  Widget build(BuildContext context) {
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
                    'assets/base/${chat.bgImages.name}.jpeg',
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
            ],
          ),
        );
      },
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
          final bool isFromUser = chat[index].isFromUser;

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
                if (index == chat.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        chat[index].timestamp.toLongLocalDateString(),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: isFromUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: <Widget>[
                      if (!isFromUser) _circleAvater(),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isFromUser ? Colors.blue : Colors.pink[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ParsedText(
                            text: chat[index].text,
                            style: TextStyle(
                              color: isFromUser ? Colors.white : Colors.black,
                            ),
                            parse: <MatchText>[
                              MatchText(
                                pattern: r'\[SoundEffects\.(.*?)\]',
                                onTap: (String p0) async {
                                  final SoundEffects? soundEffect =
                                      p0.getSoundEffectFromString();
                                  if (soundEffect == null) return;
                                  final AudioPlayer player = AudioPlayer();
                                  await player.setAsset(soundEffect.getPath());
                                  await player.play();
                                  player.dispose();
                                },
                                renderWidget: ({
                                  required String pattern,
                                  required String text,
                                }) =>
                                    const Icon(Icons.volume_up_outlined),
                              ),
                              MatchText(
                                pattern: r'\[BgImages\.(.*?)\]',
                                onTap: (String p0) async {
                                  final BgImages? bgImage =
                                      p0.getBgImageFromString();
                                  if (bgImage == null) return;
                                  context
                                      .read<ChatsCubit>()
                                      .setBgImage(bgImage);
                                },
                                renderWidget: ({
                                  required String pattern,
                                  required String text,
                                }) {
                                  final BgImages? bgImage =
                                      text.getBgImageFromString();
                                  if (bgImage == null) return Container();
                                  return Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.asset(
                                        'assets/base/${bgImage.name}.jpeg',
                                        fit: BoxFit.cover,
                                        height: 36,
                                        width: 36,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),

                          // Text(
                          //   chat[index].text,
                          //   textAlign: isFromUser ? TextAlign.right : TextAlign.left,
                          //   style: TextStyle(
                          //     color: isFromUser ? Colors.white : Colors.black,
                          //   ),
                          // ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (chat[index].attachedImage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.file(
                          File(chat[index].attachedImage),
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                        ),
                      ),
                    ),
                  ),
                if (index == 0 && isTyping)
                  Row(
                    children: <Widget>[
                      _circleAvater(),
                      Lottie.asset(
                        'assets/lotties/typing.json',
                        height: 60,
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      );

  Widget _circleAvater() => const Padding(
        padding: EdgeInsets.only(right: 8),
        child: CircleAvatar(
          backgroundColor: Colors.blue,
          foregroundImage: AssetImage("assets/base.png"),
        ),
      );
}
