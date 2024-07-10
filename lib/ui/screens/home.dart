import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/chat/chats_cubit.dart';
import '../../logic/talking/talking_cubit.dart';
import '../../utils/app_utils.dart';
import '../widgets/ai_text_input.dart';
import '../widgets/app_icon_button.dart';
import '../widgets/blinking_eyes.dart';
import '../widgets/talking_mouth.dart';
import 'chats_list_page.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Map<String, double>? _mapValues;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  void _initMap() async {
    final ByteData baseImg = await rootBundle.load("assets/base.png");
    final ui.Image decodedBaseImage =
        await decodeImageFromList(baseImg.buffer.asUint8List());
    final ByteData eyesImg = await rootBundle.load("assets/eyes_closed.png");
    final ui.Image decodedEyesImage =
        await decodeImageFromList(eyesImg.buffer.asUint8List());
    final ByteData mouthImg = await rootBundle.load("assets/mouth_closed.png");
    final ui.Image decodedMouthImage =
        await decodeImageFromList(mouthImg.buffer.asUint8List());
    if (!mounted) return;
    _mapValues = AppUtils.calculateScaledValues(
      context,
      originalWidth: decodedBaseImage.width,
      originalHeight: decodedBaseImage.height,
      eyesWidth: decodedEyesImage.width,
      eyesHeight: decodedEyesImage.height,
      eyesX: 221,
      eyesY: 428,
      mouthWidth: decodedMouthImage.width,
      mouthHeight: decodedMouthImage.height,
      mouthX: 326,
      mouthY: 617,
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatsCubit, ChatsState>(
      builder: (BuildContext context, ChatsState chatsState) {
        return BlocBuilder<TalkingCubit, TalkingState>(
          builder: (BuildContext context, TalkingState state) {
            final bool isLoading = state.status == TalkingStatus.loading;
            return PopScope(
              canPop: false,
              child: Scaffold(
                backgroundColor: Colors.blue,
                body: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.topCenter,
                  children: <Widget>[
                    Positioned.fill(
                      child: Image.asset(
                        'assets/base/${chatsState.currentChat.bgImages.name}.jpeg',
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned.fill(
                      top: null,
                      child:
                          Image.asset('assets/base.png', fit: BoxFit.contain),
                    ),
                    if (_mapValues != null)
                      BlinkingEyes(
                        eyesPath: 'assets/eyes_closed.png',
                        eyesX: _mapValues!['newEyesX'] ?? 0,
                        eyesY: _mapValues!['newEyesY'] ?? 0,
                        eyesWidth: _mapValues!['newEyesWidth'] ?? 0,
                        eyesHeight: _mapValues!['newEyesHeight'] ?? 0,
                      ),
                    const Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: AiTextInput(),
                    ),
                    if (isLoading)
                      Positioned(
                        bottom: (_mapValues?['newHeight'] ?? 0) - 130,
                        left: 140,
                        child: const CircularProgressIndicator(),
                      ),
                    if (_mapValues != null)
                      TalkingMouth(
                        mouthX: _mapValues!['newMouthX'] ?? 0,
                        mouthY: _mapValues!['newMouthY'] ?? 0,
                        mouthWidth: _mapValues!['newMouthWidth'] ?? 0,
                        mouthHeight: _mapValues!['newMouthHeight'] ?? 0,
                      ),
                    Positioned(
                      right: 8,
                      top: 28,
                      child: AppIconButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<dynamic>(
                              builder: (BuildContext context) =>
                                  const ChatsListPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
