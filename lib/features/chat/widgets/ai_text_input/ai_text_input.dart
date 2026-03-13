import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/chat.dart';
import '../../../../core/models/chat_entry.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/platform_utils.dart';
import '../../../../core/widgets/current_prompt_text.dart';
import '../../../../core/widgets/glassmorphic/glassmorphic_text_field.dart';
import '../../../../core/widgets/picker_buttons.dart';
import '../../../talking/presentation/bloc/talking_cubit.dart';
import '../../../talking/presentation/bloc/talking_state.dart';
import '../../presentation/bloc/chat_cubit.dart';
import '../../presentation/bloc/chat_state.dart';
import '../function_calling_widget.dart';
import 'picked_image_preview.dart';

class AiTextInput extends StatefulWidget {
  final bool onlyText;
  final Avatar? avatar;
  const AiTextInput({super.key, this.onlyText = false, this.avatar});

  @override
  State<AiTextInput> createState() => _AiTextInputState();
}

class _AiTextInputState extends State<AiTextInput> {
  final FocusNode _inputFocus = FocusNode();
  final TextEditingController _controller = TextEditingController();
  File? _pickedImage;
  SpeechToText? _speechToText;
  bool _speechEnabled = false;
  bool _isSubmitting = false;

  bool get _isSpeechListening => _speechToText?.isListening ?? false;

  @override
  void initState() {
    super.initState();
    _isSubmitting = false;
    _initSpeechToText();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.onlyText) {
        FocusScope.of(context).requestFocus(_inputFocus);
      }
    });
  }

  void _initSpeechToText() async {
    if (PlatformUtils.checkPlatform() == 'Web') return;
    final String platform = PlatformUtils.checkPlatform();

    // speech_to_text currently crashes on startup on macOS in this app setup.
    // Disable STT on desktop platforms that are not stable yet.
    if (platform == 'Linux' || platform == 'MacOS') {
      AppLogger.info('Speech-to-text is disabled on $platform');
      return;
    }

    bool enable = false;
    if (PlatformUtils.isMobile()) {
      final PermissionStatus status = await Permission.microphone.request();
      enable = status.isGranted;
    } else {
      // Desktop platforms (Windows, macOS) don't need permission checks
      enable = true;
    }
    if (enable) {
      try {
        _speechToText = SpeechToText();
        _speechEnabled = await _speechToText!.initialize();
      } catch (e) {
        // Handle initialization errors gracefully
        AppLogger.error('Failed to initialize speech-to-text', error: e);
        _speechEnabled = false;
      }
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return BlocListener<ChatCubit, ChatState>(
      listenWhen: (ChatState previous, ChatState current) =>
          previous.status != current.status,
      listener: (BuildContext context, ChatState state) {
        if (state.status == ChatStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage),
              backgroundColor: colorScheme.error,
            ),
          );
          // TalkingCubit manages its own error state
        }
      },
      child: BlocBuilder<ChatCubit, ChatState>(
        builder: (BuildContext context, ChatState state) {
          return BlocListener<TalkingCubit, TalkingState>(
            listenWhen: (TalkingState previous, TalkingState current) =>
                previous.runtimeType != current.runtimeType,
            listener: (BuildContext context, TalkingState talkingState) {
              if (talkingState is IdleState && _isSubmitting) {
                setState(() {
                  _isSubmitting = false;
                });
              }
            },
            child: BlocBuilder<TalkingCubit, TalkingState>(
              builder: (BuildContext context, TalkingState talkingState) {
                ChatEntry? lastUserEntry;
                final List<ChatEntry> lastFunctionCallEntries = <ChatEntry>[];
                if (state.currentChat.entries.isNotEmpty) {
                  for (final ChatEntry entry
                      in state.currentChat.entries.reversed) {
                    if (entry.entryType == EntryType.user) {
                      lastUserEntry = entry;
                      break;
                    }
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
                      PickedImagePreview(imagePath: _pickedImage!.path),
                    Stack(
                      children: <Widget>[
                        Opacity(
                          opacity:
                              widget.onlyText ||
                                  (talkingState is! GeneratingState &&
                                      talkingState is! SpeakingState &&
                                      !_isSubmitting)
                              ? 1
                              : 0,
                          child: _buildTextField(
                            currentAvatar: widget.avatar ?? const Avatar(),
                            currentLanguage: state.currentLanguage,
                            currentChat: state.currentChat,
                            functionCallingEnabled:
                                state.functionCallingEnabled,
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
                        if (lastUserEntry != null &&
                            !widget.onlyText &&
                            (talkingState.status != TalkingStatus.initial &&
                                    (talkingState is SpeakingState ||
                                        talkingState is GeneratingState) ||
                                _isSubmitting))
                          Padding(
                            padding: const EdgeInsets.only(right: 82),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Flexible(
                                  child: CurrentPromptText(
                                    prompt: lastUserEntry.body
                                        .getVisiblePrompt(),
                                  ),
                                ),
                                if (lastUserEntry.attachedImage != null)
                                  PickedImagePreview(
                                    imagePath: lastUserEntry.attachedImage!,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required Avatar currentAvatar,
    required String currentLanguage,
    required Chat currentChat,
    required bool functionCallingEnabled,
  }) => Row(
    children: <Widget>[
      if (PlatformUtils.checkPlatform() != 'Web')
        PickerButtons(onImageSelected: _onImageSelected),
      Expanded(
        child: GlassmorphicTextField(
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
            currentChat: currentChat,
            functionCallingEnabled: functionCallingEnabled,
          ),
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          minLines: 1,
          enableSpeechToText: _speechEnabled,
          isSpeechListening: _isSpeechListening,
          onSpeechPressed: () async {
            if (_isSpeechListening) {
              await _speechToText?.stop();
            } else {
              await _speechToText?.listen(
                onResult: (SpeechRecognitionResult result) => _onSpeechResult(
                  result,
                  currentAvatar: currentAvatar,
                  currentLanguage: currentLanguage,
                  currentChat: currentChat,
                  functionCallingEnabled: functionCallingEnabled,
                ),
                localeId:
                    context.read<ChatCubit>().state.currentLanguage == 'fr'
                    ? 'fr_FR'
                    : 'en_US',
                listenOptions: SpeechListenOptions(partialResults: false),
              );
            }
            setState(() {});
          },
        ),
      ),
    ],
  );

  void _onImageSelected(File? file) async {
    _inputFocus.unfocus();
    if (file != null) {
      _controller.text = AppLocalizations.of(context).describeThisImage;
      setState(() {
        _pickedImage = file;
      });
    }
    // to reopen the keyboard
    await Future<dynamic>.delayed(const Duration(milliseconds: 50)).then((_) {
      FocusScope.of(context).requestFocus(_inputFocus);
    });
  }

  void _onSpeechResult(
    SpeechRecognitionResult result, {
    required Avatar currentAvatar,
    required String currentLanguage,
    required Chat currentChat,
    required bool functionCallingEnabled,
  }) {
    setState(() {
      _controller.text = result.recognizedWords;
    });
    if (_controller.text.isEmpty) return;
    _onTextSubmitted(
      currentAvatar: currentAvatar,
      currentLanguage: currentLanguage,
      currentChat: currentChat,
      functionCallingEnabled: functionCallingEnabled,
    );
  }

  void _onTextSubmitted({
    required Avatar currentAvatar,
    required String currentLanguage,
    required Chat currentChat,
    required bool functionCallingEnabled,
  }) async {
    if (!widget.onlyText) {
      FocusScope.of(context).requestFocus(_inputFocus);
      if (_controller.text.isEmpty) return;
      // TalkingCubit now manages its own loading state
    }
    if (_controller.text.isEmpty) return;
    final String prompt = _controller.text;
    final String? attachedImage = _pickedImage?.path;
    _controller.clear();
    setState(() {
      _pickedImage = null;
      _isSubmitting = true;
    });

    // Use ChatCubit for streaming
    AppLogger.debug(
      'AiTextInput: Calling streamResponse, onlyText=${widget.onlyText}',
      tag: 'AiTextInput',
    );
    await context.read<ChatCubit>().streamResponse(
      prompt,
      onlyText: widget.onlyText,
      attachedImage: attachedImage,
      avatar: currentAvatar,
      currentChat: currentChat,
      language: currentLanguage,
      functionCallingEnabled: functionCallingEnabled,
    );

    if (!mounted) return;

    // Reset UI state to success once the streaming request safely returns
    AppLogger.debug(
      'AiTextInput: streamResponse completed, calling resetStatus. '
      'Current status: ${context.read<ChatCubit>().state.status}',
      tag: 'AiTextInput',
    );
    context.read<ChatCubit>().resetStatus();

    // TTS is handled automatically during streaming via TtsQueueManager
    // TalkingMouth will play audio from queue regardless of loading state
  }
}
