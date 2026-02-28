import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/avatar/bloc/avatar_cubit.dart';
import '../../../features/avatar/bloc/avatar_state.dart';
import '../../../features/chat/bloc/chats_cubit.dart';
import '../../../l10n/localization_manager.dart';
import '../../../logic/talking/talking_cubit.dart';
import '../../../models/chat.dart';
import '../../../models/chat_entry.dart';
import '../../../res/app_colors.dart';
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
                  if (!isLoading)
                    if (state.chatsList.isEmpty)
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  AppColors.glassSurface.withValues(alpha: 0.1),
                                  AppColors.glassSurface.withValues(
                                    alpha: 0.05,
                                  ),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.glassBorder.withValues(
                                  alpha: 0.3,
                                ),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 64,
                                  color: AppColors.onSurface.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  localized.empty,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppColors.onSurface.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      _buildList(context, state.chatsList, state.currentChat),
                  if (isLoading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context) => Container(
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          localized.listChats,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
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
              context.read<ChatsCubit>().createNewChat(
                context.read<AvatarCubit>(),
                context.read<TalkingCubit>(),
              );
              context.read<ChatsCubit>().fetchChatsList();
            },
            tooltip: 'Create new chat',
          ),
        ),
      ],
    ),
  );

  Widget _buildList(
    BuildContext context,
    List<Chat> list,
    Chat currentChat,
  ) => BlocBuilder<AvatarCubit, AvatarState>(
    builder: (BuildContext context, AvatarState state) {
      return Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          shrinkWrap: true,
          itemBuilder: (BuildContext context, int index) {
            final Chat chat = list[index];
            final bool isSelected = chat.id == currentChat.id;
            final String previewText = chat.entries.isEmpty
                ? localized.empty
                : chat.entries
                      .firstWhere(
                        (ChatEntry entry) => entry.entryType == EntryType.user,
                        orElse: () => chat.entries.first,
                      )
                      .body
                      .getVisiblePrompt();

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    context.read<ChatsCubit>().setOpenedChat(chat);
                    Navigator.of(context)
                        .push(
                          PageRouteBuilder<dynamic>(
                            pageBuilder: (_, _, _) => const ConstrainedWidth(
                              child: ChatDetailsPage(),
                            ),
                            transitionDuration: Duration.zero,
                          ),
                        )
                        .then((_) {
                          context.read<ChatsCubit>().fetchChatsList();
                        });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          AppColors.glassSurface.withValues(
                            alpha: isSelected ? 0.2 : 0.12,
                          ),
                          AppColors.glassSurface.withValues(
                            alpha: isSelected ? 0.1 : 0.06,
                          ),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : AppColors.glassBorder.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1.5,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                          blurRadius: isSelected ? 16 : 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: <Widget>[
                              // Selection indicator
                              GestureDetector(
                                onTap: () {
                                  context.read<ChatsCubit>().setCurrentChat(
                                    chat,
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? LinearGradient(
                                            colors: <Color>[
                                              AppColors.primary,
                                              AppColors.secondary,
                                            ],
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.transparent
                                          : AppColors.glassBorder.withValues(
                                              alpha: 0.4,
                                            ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    color: isSelected
                                        ? AppColors.onPrimary
                                        : AppColors.onSurface.withValues(
                                            alpha: 0.4,
                                          ),
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Chat preview
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      previewText,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.onSurface,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${chat.entries.length} messages',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              // Delete button
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.error.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_outlined,
                                    color: AppColors.error,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    context.read<ChatsCubit>().deleteChat(
                                      chat.id,
                                    );
                                  },
                                  tooltip: 'Delete chat',
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
