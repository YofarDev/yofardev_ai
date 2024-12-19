import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../l10n/localization_manager.dart';
import '../../logic/avatar/avatar_cubit.dart';
import '../../logic/avatar/avatar_state.dart';
import '../../logic/chat/chats_cubit.dart';
import '../../logic/talking/talking_cubit.dart';
import '../../models/avatar.dart';
import '../../models/chat_entry.dart';
import '../../services/tts_service.dart';
import '../../utils/extensions.dart';
import '../../utils/platform_utils.dart';
import '../pages/chat/widgets/function_calling_widget.dart';
import 'current_prompt_text.dart';
import 'picker_buttons.dart';

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
    if (PlatformUtils.checkPlatform() == 'Web') return;
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
    return BlocListener<ChatsCubit, ChatsState>(
      listenWhen: (ChatsState previous, ChatsState current) =>
          previous.status != current.status,
      listener: (BuildContext context, ChatsState state) {
        if (state.status == ChatsStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage),
              backgroundColor: Colors.red,
            ),
          );
          context.read<TalkingCubit>().setLoadingStatus(false);
        }
      },
      child: BlocBuilder<AvatarCubit, AvatarState>(
        builder: (BuildContext context, AvatarState avatarState) {
          return BlocBuilder<ChatsCubit, ChatsState>(
            builder: (BuildContext context, ChatsState state) {
              return BlocBuilder<TalkingCubit, TalkingState>(
                builder: (BuildContext context, TalkingState talkingState) {
                  ChatEntry? lastUserEntry;
                  final List<ChatEntry> lastFunctionCallEntries = <ChatEntry>[];
                  if (state.currentChat.entries.isNotEmpty) {
                    if (state.currentChat.entries.last.entryType ==
                        EntryType.user) {
                      lastUserEntry = state.currentChat.entries.lastWhere(
                        (ChatEntry c) => c.entryType == EntryType.user,
                      );
                    }
                    if (state.currentChat.entries.last.entryType ==
                        EntryType.functionCalling) {
                      for (final ChatEntry entry
                          in state.currentChat.entries.reversed) {
                        if (entry.entryType == EntryType.functionCalling) {
                          lastFunctionCallEntries.add(entry);
                        } else {
                          break;
                        }
                      }
                    }
                  }

                  return Column(
                    children: <Widget>[
                      if (_pickedImage != null)
                        _buildPickedImage(_pickedImage!.path),
                      Stack(
                        children: <Widget>[
                          Opacity(
                            opacity:
                                talkingState.status == TalkingStatus.initial
                                    ? 1
                                    : widget.onlyText
                                        ? 1
                                        : 0,
                            child: _buildTextField(
                              currentAvatar: avatarState.avatar,
                              currentLanguage: state.currentLanguage,
                              chatId: state.currentChat.id,
                            ),
                          ),
                          Column(
                            children: <Widget>[
                              ...lastFunctionCallEntries.map(
                                (ChatEntry entry) => FunctionCallingWidget(
                                  functionCallingText: entry.body,
                                ),
                              ),
                            ],
                          ),
                          if (talkingState.status != TalkingStatus.initial &&
                              !widget.onlyText &&
                              lastUserEntry != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Flexible(
                                  child: CurrentPromptText(
                                    prompt:
                                        lastUserEntry.body.getVisiblePrompt(),
                                  ),
                                ),
                                if (lastUserEntry.attachedImage != null)
                                  _buildPickedImage(
                                    lastUserEntry.attachedImage!,
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required Avatar currentAvatar,
    required String currentLanguage,
    required String chatId,
  }) =>
      Row(
        children: <Widget>[
          if (PlatformUtils.checkPlatform() != 'Web')
            PickerButtons(onImageSelected: _onImageSelected),
          Expanded(
            child: TextField(
              focusNode: _inputFocus,
              autofocus: true,
              controller: _controller,
              keyboardType: TextInputType.text,
              onChanged: (_) {
                setState(() {});
              },
              onSubmitted: (_) => _onTextSubmitted(
                currentAvatar: currentAvatar,
                currentLanguage: currentLanguage,
                chatId: chatId,
              ),
              cursorColor: Colors.blue,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.7),
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
                              onResult: (SpeechRecognitionResult result) =>
                                  _onSpeechResult(
                                result,
                                currentAvatar: currentAvatar,
                                currentLanguage: currentLanguage,
                                chatId: chatId,
                              ),
                              localeId: context
                                          .read<ChatsCubit>()
                                          .state
                                          .currentLanguage ==
                                      'fr'
                                  ? 'fr_FR'
                                  : 'en_US',
                              listenOptions:
                                  SpeechListenOptions(partialResults: false),
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
              ),
            ),
          ),
        ],
      );

  void _onImageSelected(File? file) async {
    _inputFocus.unfocus();
    if (file != null) {
      _controller.text = localized.describeThisImage;
      setState(() {
        _pickedImage = file;
      });
    }
    // to reopen the keyboard
    await Future<dynamic>.delayed(const Duration(milliseconds: 50)).then((_) {
      FocusScope.of(context).requestFocus(_inputFocus);
    });
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

  void _onSpeechResult(
    SpeechRecognitionResult result, {
    required Avatar currentAvatar,
    required String currentLanguage,
    required String chatId,
  }) {
    setState(() {
      _controller.text = result.recognizedWords;
    });
    if (_controller.text.isEmpty) return;
    _onTextSubmitted(
      currentAvatar: currentAvatar,
      currentLanguage: currentLanguage,
      chatId: chatId,
    );
  }

  void _onTextSubmitted({
    required Avatar currentAvatar,
    required String currentLanguage,
    required String chatId,
  }) async {
    if (!widget.onlyText) {
      FocusScope.of(context).requestFocus(_inputFocus);
      if (_controller.text.isEmpty) return;
      context.read<TalkingCubit>().setLoadingStatus(true);
    }
    if (_controller.text.isEmpty) return;
    final String prompt = _controller.text;
    final String? attachedImage = _pickedImage?.path;
    _controller.clear();
    setState(() {
      _pickedImage = null;
    });
    final ChatEntry? modelAnswer = await context.read<ChatsCubit>().askYofardev(
          prompt,
          attachedImage: attachedImage,
          onlyText: widget.onlyText,
          avatar: currentAvatar,
        );
    if (modelAnswer == null) return;
    if (!mounted) return;
    final AvatarConfig config = modelAnswer.getAvatarConfig();
    if (!widget.onlyText) {
      if (!mounted) return;
      final VoiceEffect voiceEffect =
          (config.specials == AvatarSpecials.outOfScreen ||
                  config.costume == null)
              ? currentAvatar.costume.getVoiceEffect()
              : config.costume!.getVoiceEffect();
      if (PlatformUtils.checkPlatform() == 'Web') {
        context.read<TalkingCubit>().speakForWeb(
              modelAnswer,
              currentLanguage,
              voiceEffect,
            );
      } else {
        context.read<TalkingCubit>().prepareToSpeak(
              chatId: chatId,
              entry: modelAnswer,
              language: currentLanguage,
              voiceEffect: voiceEffect,
            );
      }
    }
  }
}
