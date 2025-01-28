import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

import '../../logic/avatar/avatar_cubit.dart';
import '../../logic/chat/chats_cubit.dart';
import '../../logic/talking/talking_cubit.dart';
import '../../services/settings_service.dart';
import '../../utils/platform_utils.dart';
import '../pages/chat/chats_list_page.dart';
import '../pages/settings/settings_page.dart';
import 'app_icon_button.dart';
import 'constrained_width.dart';
import 'function_calling_button.dart';

class HomeButtons extends StatelessWidget {
  const HomeButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatsCubit, ChatsState>(
      builder: (BuildContext context, ChatsState state) {
        return Positioned(
          right: 8,
          top: 8,
          child: SafeArea(
            child: Column(
              children: <Widget>[
                GestureDetector(
                  onTap: () {
                    context.read<ChatsCubit>().setCurrentLanguage(
                          state.currentLanguage == 'fr' ? 'en' : 'fr',
                        );
                  },
                  child: Text(
                    state.currentLanguage == 'fr' ? '🇫🇷' : '🇬🇧',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                AppIconButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder<dynamic>(
                        pageBuilder: (_, __, ___) =>
                            const ConstrainedWidth(child: ChatsListPage()),
                        transitionDuration: Duration.zero,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                AppIconButton(
                  icon: Icons.add_outlined,
                  onPressed: () {
                    context.read<ChatsCubit>().createNewChat(
                          context.read<AvatarCubit>(),
                          context.read<TalkingCubit>(),
                        );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AppIconButton(
                    icon: Icons.settings_rounded,
                    onPressed: () async {
                      Navigator.of(context).push(
                        MaterialPageRoute<dynamic>(
                          builder: (BuildContext context) =>
                              const ConstrainedWidth(child: SettingsPage()),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const FunctionCallingButton(),
                IconButton(
                  onPressed: () async {
                    final FlutterTts flutterTts = FlutterTts();

                    await flutterTts.setLanguage('fr-FR');
                    await flutterTts.setVoice(<String, String>{
                      "name": await SettingsService().getTtsVoice('fr'),
                      "locale": 'fr-FR',
                    });
                    final String musicDirectoryPath =
                        (await getApplicationDocumentsDirectory()).path;
                    final String filename =
                        "${DateTime.now().millisecondsSinceEpoch}${PlatformUtils.checkPlatform() == 'iOS' || PlatformUtils.checkPlatform() == 'MacOS' ? '.caf' : '.wav'}";
                    final String filePath = '$musicDirectoryPath/$filename';
                    await flutterTts.awaitSynthCompletion(true);
                    final File textFile = File('$musicDirectoryPath/test.txt');
                    await textFile.writeAsString('This is a test text file.');

                    await flutterTts.synthesizeToFile(
                      'Bonjour ceci est un test. Oui baguette',
                      filePath,
                    );
                  },
                  icon: const Icon(Icons.account_box_outlined),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
