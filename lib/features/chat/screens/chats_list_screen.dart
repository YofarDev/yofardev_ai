import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../avatar/bloc/avatar_cubit.dart';
import '../../avatar/bloc/avatar_state.dart';
import '../bloc/chats_cubit.dart';
import '../bloc/chats_state.dart';
import '../../../l10n/localization_manager.dart';
import '../../talking/bloc/talking_cubit.dart';
import '../../../core/models/chat.dart';
import '../../../core/res/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/constrained_width.dart';
import 'chat_details_screen.dart';
import '../widgets/chat_list_empty_state.dart';
import '../widgets/chat_list_item.dart';

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
                decoration: BoxDecoration(
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
                      _buildList(context, state.chatsList, state.currentChat),
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
            onPressed: () => Navigator.of(context).pop(),
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

  Widget _buildList(BuildContext context, List<Chat> list, Chat currentChat) =>
      BlocBuilder<AvatarCubit, AvatarState>(
        builder: (BuildContext context, AvatarState avatarState) {
          return Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (BuildContext context, int index) {
                final Chat chat = list[index];
                final bool isSelected = chat.id == currentChat.id;

                final String previewText = _resolvePreview(chat);
                final String timeLabel = _relativeTime(
                  chat.entries.isNotEmpty ? chat.entries.last.timestamp : null,
                );

                return ChatListItem(
                  chat: chat,
                  isSelected: isSelected,
                  previewText: previewText,
                  timeLabel: timeLabel,
                  messageCount: chat.entries.length,
                  onTap: () => _openChat(context, chat),
                  onDismissed: () =>
                      context.read<ChatsCubit>().deleteChat(chat.id),
                  onDismissConfirm: () => _confirmDelete(context),
                );
              },
            ),
          );
        },
      );

  void _openChat(BuildContext context, Chat chat) {
    context.read<ChatsCubit>().setCurrentChat(chat);
    context.read<ChatsCubit>().setOpenedChat(chat);
    Navigator.of(context)
        .push(
          PageRouteBuilder<dynamic>(
            pageBuilder: (_, _, _) =>
                const ConstrainedWidth(child: ChatDetailsPage()),
            transitionDuration: Duration.zero,
          ),
        )
        .then((_) {
          context.read<ChatsCubit>().fetchChatsList();
        });
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete chat?'),
        content: const Text('This conversation will be permanently removed.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _resolvePreview(Chat chat) {
    if (chat.entries.isEmpty) return localized.empty;
    for (int i = chat.entries.length - 1; i >= 0; i--) {
      final String body = chat.entries[i].body;
      if (body.trim().isEmpty) continue;
      try {
        final String visible = body.getVisiblePrompt();
        if (visible.trim().isNotEmpty) return visible;
      } catch (_) {
        final String raw = body.trim();
        if (raw.isNotEmpty) return raw;
      }
    }
    return localized.empty;
  }

  String _relativeTime(DateTime? date) {
    if (date == null) return '';
    final Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
