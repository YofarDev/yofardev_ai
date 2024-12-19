import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/chat/chats_cubit.dart';
import 'app_icon_button.dart';

class FunctionCallingButton extends StatelessWidget {
  const FunctionCallingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatsCubit, ChatsState>(
      builder: (BuildContext context, ChatsState state) {
        return AppIconButton(
          icon: state.functionCallingEnabled ? Icons.code : Icons.code_off,
          onPressed: () async {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.functionCallingEnabled
                      ? 'Function calling OFF'
                      : 'Function calling ON',
                ),
                duration: const Duration(milliseconds: 500),
              ),
            );
            context.read<ChatsCubit>().toggleFunctionCalling();
          },
        );
      },
    );
  }
}
