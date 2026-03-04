import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../avatar/bloc/avatar_cubit.dart';
import '../bloc/chats_cubit.dart';
import '../bloc/chats_state.dart';
import '../../../l10n/localization_manager.dart';
import '../../talking/bloc/talking_cubit.dart';
import '../../../core/res/app_colors.dart';
import '../widgets/chat_list_container.dart';
import '../widgets/chat_list_empty_state.dart';

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
                    _buildAppBar(context),
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

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.surface.withValues(alpha: 0.9),
            AppColors.surface.withValues(alpha: 0.7),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AppColors.glassBorder.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 8),
          Text(
            localized.listChats,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.secondary.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.glassBorder.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.add_circle_outlined),
              onPressed: () {
                context.read<ChatsCubit>().createNewChat();
              },
              tooltip: 'Create new chat',
            ),
          ),
        ],
      ),
    );
  }
}
