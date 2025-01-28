import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/localization_manager.dart';
import '../../../logic/avatar/avatar_cubit.dart';
import '../../../logic/avatar/avatar_state.dart';
import '../../../logic/chat/chats_cubit.dart';
import '../../../logic/talking/talking_cubit.dart';
import '../../../models/avatar.dart';
import '../../../models/chat.dart';
import '../../../models/chat_entry.dart';
import '../../../utils/extensions.dart';
import '../../widgets/constrained_width.dart';
import 'chat_details_page.dart';

class ChatsListPage extends StatelessWidget {
  const ChatsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<ChatsCubit>().fetchChatsList();
    return BlocBuilder<ChatsCubit, ChatsState>(
      builder: (BuildContext context, ChatsState state) {
        final bool isLoading = state.status == ChatsStatus.loading;
        return SafeArea(
          child: Scaffold(
            body: Column(
              children: <Widget>[
                _buildAppBar(context),
                if (!isLoading)
                  if (state.chatsList.isEmpty)
                    Center(child: Text(localized.empty))
                  else
                    _buildList(
                      context,
                      state.chatsList,
                      state.currentChat,
                    ),
                if (isLoading) const CircularProgressIndicator(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context) => AppBar(
        title: Text(localized.listChats),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_circle_outlined),
            onPressed: () {
              context.read<ChatsCubit>().createNewChat(
                    context.read<AvatarCubit>(),
                    context.read<TalkingCubit>(),
                  );
              context.read<ChatsCubit>().fetchChatsList();
            },
          ),
        ],
      );

  Widget _buildList(BuildContext context, List<Chat> list, Chat currentChat) =>
      BlocBuilder<AvatarCubit, AvatarState>(
        builder: (BuildContext context, AvatarState state) {
          return Expanded(
            child: ListView.builder(
              itemCount: list.length,
              shrinkWrap: true,
              itemBuilder: (BuildContext context, int index) {
                final Chat chat = list[index];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.9,
                            child: Image.asset(
                              list[index].avatar.background.getPath(),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            context.read<ChatsCubit>().setOpenedChat(chat);
                            Navigator.of(context)
                                .push(
                              PageRouteBuilder<dynamic>(
                                pageBuilder: (_, __, ___) =>
                                    const ConstrainedWidth(
                                  child: ChatDetailsPage(),
                                ),
                                transitionDuration: Duration.zero,
                              ),
                            )
                                .then((_) {
                              context.read<ChatsCubit>().fetchChatsList();
                            });
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: InkWell(
                                  onTap: () {
                                    context
                                        .read<ChatsCubit>()
                                        .setCurrentChat(chat);
                                  },
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: (chat.id == currentChat.id)
                                          ? Colors.blue.withValues(alpha: 0.8)
                                          : Colors.black.withValues(alpha: 0.2),
                                    ),
                                    child: const Icon(
                                      Icons.check_circle_outlined,
                                      color: Colors.white,
                                      // size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 16,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white60,
                                    ),
                                    child: Text(
                                      chat.entries.isEmpty
                                          ? localized.empty
                                          : chat.entries
                                              .firstWhere(
                                                (ChatEntry entry) =>
                                                    entry.entryType ==
                                                    EntryType.user,
                                              )
                                              .body
                                              .getVisiblePrompt(),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      // style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color:
                                        Colors.red[600]!.withValues(alpha: 0.5),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      context
                                          .read<ChatsCubit>()
                                          .deleteChat(chat.id);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
}
