import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../logic/chat/chats_cubit.dart';
import '../../../models/avatar_backgrounds.dart';

class BackgroundAvatar extends StatelessWidget {
  const BackgroundAvatar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatsCubit, ChatsState>(
      builder: (BuildContext context, ChatsState state) {
        return Positioned.fill(
          child: Image.asset(
            state.currentChat.bg.getPath(),
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}
