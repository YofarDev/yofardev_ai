import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../logic/avatar/avatar_cubit.dart';
import '../../logic/chat/chats_cubit.dart';
import '../../logic/talking/talking_cubit.dart';
import '../../models/avatar_backgrounds.dart';
import '../../models/chat_entry.dart';
import '../../utils/extensions.dart';
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
  final FocusNode _inputFocus = FocusNode();
  final TextEditingController _controller = TextEditingController();
  File? _pickedImage;
  late SpeechToText _speechToText;
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _initSpeechToText();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.onlyText) {
        FocusScope.of(context).requestFocus(_inputFocus);
      }
    });
  }

  void _initSpeechToText() async {
    final PermissionStatus status = await Permission.microphone.request();
    if (status.isGranted) {
      _speechToText = SpeechToText();
      _speechEnabled = await _speechToText.initialize();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TalkingCubit, TalkingState>(
      listenWhen: (TalkingState previous, TalkingState current) =>
          previous.status != current.status,
      listener: (BuildContext context, TalkingState state) {
        if (state.status == TalkingStatus.success) {
          final List<AvatarBackgrounds> bgs =
              state.answer.annotations.getBgImages();
          if (bgs.length == 1) {
            final AvatarBackgrounds bgImage = bgs.first;
            if (!mounted) return;
            context.read<ChatsCubit>().setBgImage(bgImage, currentOnly: true);
          }
        }
      },
      child: BlocBuilder<ChatsCubit, ChatsState>(
        builder: (BuildContext context, ChatsState state) {
          return BlocBuilder<TalkingCubit, TalkingState>(
            builder: (BuildContext context, TalkingState talkingState) {
              ChatEntry? lastUserEntry;
              if (state.currentChat.entries.isNotEmpty) {
                lastUserEntry = state.currentChat.entries
                    .lastWhere((ChatEntry c) => c.isFromUser);
              }
              return Column(
                children: <Widget>[
                  if (_pickedImage != null)
                    _buildPickedImage(_pickedImage!.path),
                  Stack(
                    children: <Widget>[
                      Opacity(
                        opacity: talkingState.status == TalkingStatus.initial
                            ? 1
                            : widget.onlyText
                                ? 1
                                : 0,
                        child: _buildTextField(),
                      ),
                      if (talkingState.status != TalkingStatus.initial &&
                          !widget.onlyText &&
                          lastUserEntry != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Flexible(
                              child: CurrentPromptText(
                                prompt: lastUserEntry.text.getVisiblePrompt(),
                              ),
                            ),
                            if (lastUserEntry.attachedImage.isNotEmpty)
                              _buildPickedImage(lastUserEntry.attachedImage),
                          ],
                        ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTextField() => TextField(
        focusNode: _inputFocus,
        autofocus: true,
        controller: _controller,
        keyboardType: TextInputType.text,
        onChanged: (_) {
          setState(() {});
        },
        onSubmitted: (_) async {
          if (!widget.onlyText) {
            FocusScope.of(context).requestFocus(_inputFocus);
            if (_controller.text.isEmpty) return;
            context.read<TalkingCubit>().isLoading();
          }
          if (_controller.text.isEmpty) return;
          final String prompt = _controller.text;
          final String? attachedImage = _pickedImage?.path;
          _controller.clear();
          setState(() {
            _pickedImage = null;
          });

          final Map<String, dynamic> responseMap =
              await context.read<ChatsCubit>().askYofardev(
                    prompt,
                    attachedImage: attachedImage,
                    onlyText: widget.onlyText,
                    avatar: context.read<AvatarCubit>().state.avatar,
                  );
          if (!widget.onlyText) {
            if (!mounted) return;
            context.read<TalkingCubit>().prepareToSpeak(responseMap);
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
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (_speechEnabled)
                IconButton(
                  icon: Icon(
                    Icons.mic,
                    color: _speechToText.isListening ? Colors.red : null,
                  ),
                  onPressed: () async {
                    if (_speechToText.isListening) {
                      await _speechToText.stop();
                    } else {
                      await _speechToText.listen(
                        onResult: _onSpeechResult,
                        localeId: 'fr_FR',
                      );
                    }
                    setState(() {});
                  },
                ),
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    _pickedImage = null;
                    setState(() {});
                  },
                ),
            ],
          ),
          prefixIcon: _imagePickerButton(),
        ),
      );

  Widget _imagePickerButton() {
    return IconButton(
      icon: const Icon(Icons.image_outlined),
      onPressed: () async {
        _inputFocus.unfocus();
        final ImagePicker picker = ImagePicker();
        final XFile? picked =
            await picker.pickImage(source: ImageSource.gallery);
        if (picked != null) {
          final Directory appDir = await getApplicationDocumentsDirectory();
          final String fileName = path.basename(picked.path);
          final File savedImage = File('${appDir.path}/$fileName');
          await File(picked.path).copy(savedImage.path);
          _controller.text = 'Décris cette image';
          if (!mounted) return;
          setState(() {
            _pickedImage = savedImage;
          });
          FocusScope.of(context).requestFocus(_inputFocus);
        }
      },
    );
  }

  Widget _buildPickedImage(String path) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            width: 100,
            height: 100,
          ),
        ),
      );

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _controller.text = result.recognizedWords;
    });
  }
}
