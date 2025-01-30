import 'dart:async';
import 'dart:convert';

import 'package:audio_analyzer/audio_analyzer.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/localization_manager.dart';
import '../../models/avatar.dart';
import '../../models/chat.dart';
import '../../models/chat_entry.dart';
import '../../repositories/yofardev_repository.dart';
import '../../services/cache_service.dart';
import '../../services/chat_history_service.dart';
import '../../services/settings_service.dart';
import '../../services/tts_service.dart';
import '../../utils/extensions.dart';
import '../../utils/platform_utils.dart';
import '../avatar/avatar_cubit.dart';
import '../talking/talking_cubit.dart';

part 'chats_state.dart';

class ChatsCubit extends Cubit<ChatsState> {
  ChatsCubit() : super(const ChatsState());

  late YofardevRepository _yofardevRepository;

  void createNewChat(AvatarCubit avatarCubit, TalkingCubit talkingCubit) async {
    emit(state.copyWith(status: ChatsStatus.updating));
    final Chat newChat = await ChatHistoryService().createNewChat();
    emit(
      state.copyWith(
        status: ChatsStatus.success,
        chatsList: <Chat>[newChat, ...state.chatsList],
        currentChat: newChat,
      ),
    );
    avatarCubit.loadAvatar(newChat.id);
    talkingCubit.init();
  }

  void init() async {
    getCurrentChat();
    setCurrentLanguage(
      PlatformUtils.checkPlatform() == 'Web' ||
              PlatformUtils.checkPlatform() == 'MacOS'
          ? "fr"
          : await SettingsService().getLanguage() ?? 'fr',
    );
  }

  void toggleFunctionCalling() {
    emit(
      state.copyWith(
        functionCallingEnabled: !state.functionCallingEnabled,
      ),
    );
  }

  Future<void> prepareWaitingSentences(List<String> sentences) async {
    if (PlatformUtils.checkPlatform() == 'Web') {
      emit(state.copyWith(initializing: false));
      return;
    }
    emit(state.copyWith(initializing: true));
    // await CacheService.clearWaitingSentencesMap(state.currentLanguage);
    final List<Map<String, dynamic>> map =
        await CacheService.getWaitingSentencesMap(state.currentLanguage) ??
            <Map<String, dynamic>>[];
    for (final String sentence in sentences) {
      if (map.any(
        (Map<String, dynamic> element) => element['sentence'] == sentence,
      )) {
        continue;
      } else {
        final String audioPath = await TtsService().textToFrenchMaleVoice(
          text: sentence,
          language: state.currentLanguage,
          voiceEffect: AvatarCostume.none.getVoiceEffect(),
        );
        final List<int> amplitudes =
            await AudioAnalyzer().getAmplitudes(audioPath);
        map.add(<String, dynamic>{
          'sentence': sentence,
          'audioPath': audioPath,
          'amplitudes': amplitudes,
        });
        emit(
          state.copyWith(
            audioPathsWaitingSentences: map,
          ),
        );
      }
    }
    await CacheService.setWaitingSentencesMap(map, state.currentLanguage);
    emit(
      state.copyWith(
        audioPathsWaitingSentences: map,
        initializing: false,
      ),
    );
  }

  void shuffleWaitingSentences() async {
    final List<Map<String, dynamic>> list = state.audioPathsWaitingSentences;
    list.shuffle();
    emit(
      state.copyWith(
        audioPathsWaitingSentences: list,
      ),
    );
  }

  void getCurrentChat() async {
    emit(state.copyWith(status: ChatsStatus.loading));
    final Chat currentChat = await ChatHistoryService().getCurrentChat();
    final bool soundEffectsEnabled = await SettingsService().getSoundEffects();
    emit(
      state.copyWith(
        status: ChatsStatus.success,
        currentChat: currentChat,
        soundEffectsEnabled: soundEffectsEnabled,
        currentLanguage:
            await SettingsService().getLanguage() ?? currentChat.language,
      ),
    );
  }

  void setCurrentLanguage(String language) async {
    await SettingsService().setLanguage(language);
    await LocalizationManager().initialize(language);
    emit(state.copyWith(currentLanguage: language));
  }

  void setSoundEffects(bool soundEffectsEnabled) async {
    emit(state.copyWith(soundEffectsEnabled: soundEffectsEnabled));
    await SettingsService().setSoundEffects(soundEffectsEnabled);
  }

  void fetchChatsList() async {
    emit(state.copyWith(status: ChatsStatus.loading));
    final List<Chat> chatsList =
        (await ChatHistoryService().getChatsList()).reversed.toList();
    emit(state.copyWith(status: ChatsStatus.success, chatsList: chatsList));
  }

  void deleteChat(String id) async {
    emit(state.copyWith(status: ChatsStatus.updating));
    await ChatHistoryService().deleteChat(id);
    final List<Chat> chatsList = state.chatsList;
    chatsList.removeWhere((Chat element) => element.id == id);
    emit(state.copyWith(chatsList: chatsList, status: ChatsStatus.success));
  }

  void setCurrentChat(Chat chat) {
    emit(state.copyWith(currentChat: chat));
    ChatHistoryService().setCurrentChatId(chat.id);
  }

  void setOpenedChat(Chat chat) {
    emit(state.copyWith(openedChat: chat));
  }

  Future<List<Map<String, dynamic>>> _checkFunctionCalling({
    required String lastUserMessage,
    required Avatar avatar,
    required bool onlyText,
  }) async {
    final StreamController<List<Map<String, dynamic>>> streamController =
        StreamController<List<Map<String, dynamic>>>();
    final List<Map<String, dynamic>> previousResults = <Map<String, dynamic>>[];
    _yofardevRepository
        .getFunctionsResultsStream(
      chat: onlyText ? state.openedChat : state.currentChat,
      lastUserMessage: lastUserMessage,
    )
        .listen(
      (Map<String, dynamic> result) {
        final List<Map<String, dynamic>> newResults = <Map<String, dynamic>>[
          result,
        ];
        debugPrint('functionCalling result: $result');
        streamController.add(newResults);
        previousResults.add(result);
      },
      onDone: () => streamController.close(),
    );
    await for (final List<Map<String, dynamic>> functionsResults
        in streamController.stream) {
      final ChatEntry functionCallingEntry = ChatEntry(
        id: const Uuid().v4(),
        entryType: EntryType.functionCalling,
        body: jsonEncode(functionsResults),
        timestamp: DateTime.now(),
      );
      Chat chat = onlyText ? state.openedChat : state.currentChat;
      chat = chat.copyWith(
        entries: <ChatEntry>[...chat.entries, functionCallingEntry],
      );
      emit(
        state.copyWith(
          openedChat: onlyText ? chat : null,
          currentChat: onlyText ? null : chat,
        ),
      );
    }
    final List<Map<String, dynamic>> finalResultsToSend =
        <Map<String, dynamic>>[];
    for (final Map<String, dynamic> item in previousResults) {
      if (item['intermediate'] != true) {
        item.remove('intermediate');
        for (final String key in item.keys) {
          if (key != 'result') {
            String value = item[key].toString();
            if (value.characters.length > 200) {
              value = '${value.substring(0, 200)} [...]';
            }
            value = '${value.replaceAll('\n', '')}\n';
            item[key] = value;
          }
        }
        finalResultsToSend.add(item);
      }
    }
    return finalResultsToSend;
  }

  Future<ChatEntry> _getNewEntry({
    required String lastUserMessage,
    required Avatar avatar,
    required bool onlyText,
    String? attachedImage,
  }) async {
    final List<Map<String, dynamic>> finalResultsToSend =
        state.functionCallingEnabled
            ? await _checkFunctionCalling(
                lastUserMessage: lastUserMessage,
                avatar: avatar,
                onlyText: onlyText,
              )
            : <Map<String, dynamic>>[];
    final String languageCode = await SettingsService().getLanguage() ?? 'fr';
    final String wrappedUserMessage =
        "${localized.currentDate} : ${DateTime.now().toLongLocalDateString(language: languageCode)}\n${localized.currentAvatarConfig} :\n{\n$avatar\n}${finalResultsToSend.isNotEmpty ? "\n${localized.resultsFunctionCalling} :\n$finalResultsToSend\n" : ''}\n${localized.userMessage} : \n'''$lastUserMessage'''";
    final ChatEntry newUserEntry = ChatEntry(
      id: const Uuid().v4(),
      entryType: EntryType.user,
      body: wrappedUserMessage,
      timestamp: DateTime.now(),
      attachedImage: attachedImage,
    );

    return newUserEntry;
  }

  Future<ChatEntry?> askYofardev(
    String prompt, {
    required bool onlyText,
    String? attachedImage,
    required Avatar avatar,
  }) async {
    _yofardevRepository = YofardevRepository();
    Chat chat = onlyText ? state.openedChat : state.currentChat;
    final String temporaryId = const Uuid().v4();
    final ChatEntry temporaryEntry = ChatEntry(
      id: temporaryId,
      entryType: EntryType.user,
      body: "${localized.userMessage} : \n'''$prompt'''",
      timestamp: DateTime.now(),
      attachedImage: attachedImage,
    );
    chat = chat.copyWith(entries: <ChatEntry>[...chat.entries, temporaryEntry]);
    emit(
      state.copyWith(
        status: ChatsStatus.typing,
        openedChat: onlyText ? chat : null,
        currentChat: onlyText ? null : chat,
      ),
    );
    final ChatEntry userEntry = await _getNewEntry(
      lastUserMessage: prompt,
      avatar: avatar,
      attachedImage: attachedImage,
      onlyText: onlyText,
    );
    chat = onlyText
        ? state.openedChat
        : state.currentChat; // need to get updated chat
    chat = chat.copyWith(entries: <ChatEntry>[...chat.entries]);
    final int index = chat.entries.indexWhere(
      (ChatEntry element) => element.id == temporaryId,
    );
    chat.entries[index] = userEntry;
    emit(
      state.copyWith(
        openedChat: onlyText ? chat : null,
        currentChat: onlyText ? null : chat,
      ),
    );
    try {
      final ChatEntry newModelEntry =
          await _yofardevRepository.askYofardevAi(chat);
      final List<ChatEntry> entries = <ChatEntry>[
        ...chat.entries,
        newModelEntry,
      ];
      chat = chat.copyWith(entries: entries);
      emit(
        state.copyWith(
          openedChat: onlyText ? chat : null,
          currentChat: onlyText ? null : chat,
          status: ChatsStatus.success,
        ),
      );
      await ChatHistoryService().updateChat(
        chatId: chat.id,
        updatedChat: chat,
      );
      return newModelEntry;
    } catch (e) {
      debugPrint(e.toString());
      emit(
        state.copyWith(
          status: ChatsStatus.error,
          errorMessage: e.toString(),
        ),
      );
      return null;
    }
  }

  Future<void> updateBackgroundOpenedChat(AvatarBackgrounds bg) async {
    emit(state.copyWith(status: ChatsStatus.updating));
    final Chat chat = state.openedChat;
    emit(
      state.copyWith(
        openedChat: chat.copyWith(avatar: chat.avatar.copyWith(background: bg)),
        status: ChatsStatus.success,
      ),
    );
    await ChatHistoryService().updateAvatar(
      chat.id,
      chat.avatar.copyWith(background: bg),
    );
  }

  void updateAvatarOpenedChat(AvatarConfig avatarConfig) async {
    emit(state.copyWith(status: ChatsStatus.updating));
    final Chat chat = state.openedChat;
    final Avatar avatar = chat.avatar.copyWith(
      hat: avatarConfig.hat,
      top: avatarConfig.top,
      background: avatarConfig.background,
      glasses: avatarConfig.glasses,
      specials: avatarConfig.specials,
      costume: avatarConfig.costume,
    );
    emit(
      state.copyWith(
        openedChat: chat.copyWith(avatar: avatar),
        status: ChatsStatus.success,
      ),
    );
    await ChatHistoryService().updateAvatar(
      chat.id,
      avatar,
    );
  }
}
