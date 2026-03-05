import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../avatar/bloc/avatar_cubit.dart';
import '../bloc/chats_cubit.dart';
import '../bloc/chats_state.dart';
import '../../talking/presentation/bloc/talking_cubit.dart';
import '../../../core/res/app_colors.dart';
import '../widgets/chat_list_container.dart';
import '../widgets/chat_list_empty_state.dart';
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
    context.read<ChatsCubit>().fetchChatsList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatsCubit, ChatsState>(
      listener: (BuildContext context, ChatsState state) {
        if (state.chatCreated) {
          // Handle cross-feature coordination when chat is created
          context.read<AvatarCubit>().loadAvatar(state.currentChat.id);
          context.read<TalkingCubit>().init();
          // Refresh the chat list after creation
          context.read<ChatsCubit>().fetchChatsList();
        }
      },
      child: BlocBuilder<ChatsCubit, ChatsState>(
        builder: (BuildContext context, ChatsState state) {
          final bool isLoading = state.status == ChatsStatus.loading;
          return SafeArea(
            child: Scaffold(
              body: Container(
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
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (state.chatsList.isEmpty)
                      const ChatListEmptyState()
                    else
                      ChatListContainer(
                        chats: state.chatsList,
                        currentChat: state.currentChat,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
