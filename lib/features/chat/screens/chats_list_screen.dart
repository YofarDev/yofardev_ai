import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';

import '../../avatar/presentation/bloc/avatar_cubit.dart';
import '../presentation/bloc/chat_cubit.dart';
import '../presentation/bloc/chat_state.dart';
import '../presentation/bloc/chat_title_cubit.dart';
import '../presentation/bloc/chat_title_state.dart';
import '../../talking/presentation/bloc/talking_cubit.dart';
import '../../../core/res/app_colors.dart';
import '../widgets/chat_list_container.dart';
import '../widgets/chat_list_empty_state.dart';
import '../widgets/chat_list_shimmer_loading.dart';
import '../widgets/chats_list_app_bar.dart';

class ChatsListPage extends StatefulWidget {
  const ChatsListPage({super.key});

  @override
  State<ChatsListPage> createState() => _ChatsListPageState();
}

class _ChatsListPageState extends State<ChatsListPage> {
  @override
  void initState() {
    super.initState();
    // Fetch once on init, not on every build
    context.read<ChatCubit>().fetchChatsList();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: <SingleChildWidget>[
        // Listen for chat creation events
        BlocListener<ChatCubit, ChatState>(
          listener: (BuildContext context, ChatState state) {
            if (state.chatCreated) {
              // Handle cross-feature coordination when chat is created
              context.read<AvatarCubit>().loadAvatar(state.currentChat.id);
              context.read<TalkingCubit>().init();
              // Refresh the chat list after creation
              context.read<ChatCubit>().fetchChatsList();
            }
          },
        ),
        // Listen for title generation completion to refresh the list
        BlocListener<ChatTitleCubit, ChatTitleState>(
          listenWhen: (_, ChatTitleState state) =>
              state.lastGeneratedTitle != null,
          listener: (_, ChatTitleState state) {
            // Refresh chat list to show the newly generated title
            context.read<ChatCubit>().fetchChatsList();
          },
        ),
      ],
      child: SafeArea(
        child: Scaffold(
          body: BlocBuilder<ChatCubit, ChatState>(
            builder: (BuildContext context, ChatState state) {
              final bool isLoading = state.status == ChatStatus.loading;
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[AppColors.background, AppColors.surface],
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    const ChatsListAppBar(),
                    if (isLoading)
                      const ChatListShimmerLoading()
                    else if (state.chatsList.isEmpty)
                      const ChatListEmptyState()
                    else
                      ChatListContainer(
                        chats: state.chatsList,
                        currentChat: state.currentChat,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
