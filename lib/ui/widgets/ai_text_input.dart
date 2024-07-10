import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/chat/chats_cubit.dart';
import '../../logic/talking/talking_cubit.dart';
import 'current_prompt_text.dart';

class AiTextInput extends StatefulWidget {
  final bool onlyText;
  const AiTextInput({
    super.key,
    this.onlyText = false,
  });

  @override
  State<AiTextInput> createState() => _AiTextInputState();
}

class _AiTextInputState extends State<AiTextInput> {
  late FocusNode inputFieldNode;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    inputFieldNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.onlyText) {
        FocusScope.of(context).requestFocus(inputFieldNode);
      }
    });
  }

  @override
  void dispose() {
    inputFieldNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // if (widget.onlyText) return _buildTextField();
    return BlocBuilder<TalkingCubit, TalkingState>(
      builder: (BuildContext context, TalkingState state) {
        return Stack(
          children: <Widget>[
            Opacity(
              opacity: state.status == TalkingStatus.initial
                  ? 1
                  : widget.onlyText
                      ? 1
                      : 0,
              child: _buildTextField(),
            ),
            if (state.status != TalkingStatus.initial && !widget.onlyText)
              CurrentPromptText(prompt: state.prompt),
          ],
        );
      },
    );
  }

  Widget _buildTextField() => TextField(
        focusNode: inputFieldNode,
        controller: _controller,
        onChanged: (_) {
          setState(() {});
        },
        onSubmitted: (_) async {
          if (!widget.onlyText) {
            FocusScope.of(context).requestFocus(inputFieldNode);
          }
          if (_controller.text.isEmpty) return;
          final String prompt = _controller.text;
          _controller.clear();
          if (widget.onlyText) {
            context.read<ChatsCubit>().onTextPromptSubmitted(prompt);
          } else {
            context.read<TalkingCubit>().onTextPromptSubmitted(prompt);
          }
        },
        cursorColor: Colors.blue,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.3),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          suffixIcon: (_controller.text.isNotEmpty)
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    setState(() {});
                  },
                )
              : null,
        ),
      );
}
