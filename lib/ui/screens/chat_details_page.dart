import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_parsed_text/flutter_parsed_text.dart';
import 'package:just_audio/just_audio.dart';

import '../../logic/avatar/avatar_cubit.dart';
import '../../logic/history/history_cubit.dart';
import '../../models/bg_images.dart';
import '../../models/chat_entry.dart';
import '../../models/sound_effects.dart';
import '../widgets/ai_text_input.dart';

class ChatDetailsPage extends StatelessWidget {
  const ChatDetailsPage();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvatarCubit, AvatarState>(
      builder: (BuildContext context, AvatarState avatarState) {
        return BlocBuilder<HistoryCubit, HistoryState>(
          buildWhen: (HistoryState previous, HistoryState current) =>
              previous.status != current.status,
          builder: (BuildContext context, HistoryState state) {
            return Scaffold(
              body: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.3,
                      child: Image.asset(
                        'assets/base/${avatarState.bgImage.name}.jpeg',
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
                            state.currentChat.reversed.toList(),
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
                      child: Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          color: Colors.blue[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(
                            Icons.arrow_back_ios_new_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildConversation(BuildContext contex, List<ChatEntry> chat) =>
      ListView.builder(
        itemCount: chat.length,
        reverse: true,
        itemBuilder: (BuildContext context, int index) {
          final bool isFromUser = chat[index].isFromUser;
          return Padding(
            padding: EdgeInsets.only(
              bottom: 8,
              left: isFromUser ? 32 : 0,
              right: isFromUser ? 0 : 32,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment:
                  isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: <Widget>[
                if (!isFromUser)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: CircleAvatar(
                      foregroundImage: AssetImage("assets/base.png"),
                    ),
                  ),
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
                                getSoundEffectFromString(p0);
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
                            final BgImages? bgImage = getBgImageFromString(p0);
                            if (bgImage == null) return;
                            context.read<AvatarCubit>().setBgImage(bgImage);
                          },
                          renderWidget: ({
                            required String pattern,
                            required String text,
                          }) {
                            final BgImages? bgImage =
                                getBgImageFromString(text);
                            if (bgImage == null) return Container();
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.asset(
                                'assets/base/${bgImage.name}.jpeg',
                                fit: BoxFit.cover,
                                height: 36,
                                width: 36,
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
          );
        },
      );
}
