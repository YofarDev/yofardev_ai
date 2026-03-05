import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/res/app_colors.dart';
import '../bloc/chats_cubit.dart';
import '../../../l10n/localization_manager.dart';

/// App bar for the chats list screen
class ChatsListAppBar extends StatelessWidget {
  const ChatsListAppBar({super.key});

  @override
  Widget build(BuildContext context) {
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
