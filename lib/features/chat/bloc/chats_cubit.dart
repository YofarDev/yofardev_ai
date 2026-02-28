import 'dart:async';

import 'package:audio_analyzer/audio_analyzer.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/localization_manager.dart';
import '../../../logic/talking/talking_cubit.dart';
import '../../../core/models/avatar_config.dart';
import '../../../models/chat.dart';
import '../../../models/chat_entry.dart';
import '../../../repositories/yofardev_repository.dart';
import '../../../services/cache_service.dart';
import '../../../services/chat_history_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/tts_service.dart';
import '../../../utils/extensions.dart';
import '../../../utils/logger.dart';
import '../../../utils/platform_utils.dart';
import '../../avatar/bloc/avatar_cubit.dart';

part 'chat_state.dart';

class ChatsCubit extends Cubit<ChatsState> {
  ChatsCubit({
    required ChatHistoryService chatHistoryService,
    required SettingsService settingsService,
    required YofardevRepository yofardevRepository,
  }) : _chatHistoryService = chatHistoryService,
       _settingsService = settingsService,
       _yofardevRepository = yofardevRepository,
       super(const ChatsState());

  late final ChatHistoryService _chatHistoryService;
  late final SettingsService _settingsService;
  late final YofardevRepository _yofardevRepository;

  void createNewChat(AvatarCubit avatarCubit, TalkingCubit talkingCubit) async {
    emit(state.copyWith(status: ChatsStatus.updating));
    final Chat newChat = await _chatHistoryService.createNewChat();
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
          : await _settingsService.getLanguage() ?? 'fr',
    );
  }

  void toggleFunctionCalling() {
    emit(state.copyWith(functionCallingEnabled: !state.functionCallingEnabled));
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
        final List<int> amplitudes = await AudioAnalyzer().getAmplitudes(
          audioPath,
        );
        map.add(<String, dynamic>{
          'sentence': sentence,
          'audioPath': audioPath,
          'amplitudes': amplitudes,
        });
        emit(state.copyWith(audioPathsWaitingSentences: map));
      }
    }
    await CacheService.setWaitingSentencesMap(map, state.currentLanguage);
    emit(state.copyWith(audioPathsWaitingSentences: map, initializing: false));
  }

  void shuffleWaitingSentences() {
    final List<Map<String, dynamic>> list = state.audioPathsWaitingSentences;
    list.shuffle();
    emit(state.copyWith(audioPathsWaitingSentences: list));
  }

  void getCurrentChat() async {
    emit(state.copyWith(status: ChatsStatus.loading));
    final Chat currentChat = await _chatHistoryService.getCurrentChat();
    final bool soundEffectsEnabled = await _settingsService.getSoundEffects();
    emit(
      state.copyWith(
        status: ChatsStatus.success,
        currentChat: currentChat,
        soundEffectsEnabled: soundEffectsEnabled,
        currentLanguage:
            await _settingsService.getLanguage() ?? currentChat.language,
      ),
    );
  }

  void setCurrentLanguage(String language) async {
    await _settingsService.setLanguage(language);
    await LocalizationManager().initialize(language);
    emit(state.copyWith(currentLanguage: language));
  }

  void setSoundEffects(bool soundEffectsEnabled) async {
    emit(state.copyWith(soundEffectsEnabled: soundEffectsEnabled));
    await _settingsService.setSoundEffects(soundEffectsEnabled);
  }

  void fetchChatsList() async {
    emit(state.copyWith(status: ChatsStatus.loading));
    final List<Chat> chatsList = (await _chatHistoryService.getChatsList())
        .reversed
        .toList();
    emit(state.copyWith(status: ChatsStatus.success, chatsList: chatsList));
  }

  void deleteChat(String id) async {
    emit(state.copyWith(status: ChatsStatus.updating));
    await _chatHistoryService.deleteChat(id);
    final List<Chat> chatsList = state.chatsList;
    chatsList.removeWhere((Chat element) => element.id == id);
    emit(state.copyWith(chatsList: chatsList, status: ChatsStatus.success));
  }

  void setCurrentChat(Chat chat) {
    emit(state.copyWith(currentChat: chat));
    _chatHistoryService.setCurrentChatId(chat.id);
  }

  void setOpenedChat(Chat chat) {
    emit(state.copyWith(openedChat: chat));
  }

  Future<ChatEntry> _getNewEntry({
    required String lastUserMessage,
    required Avatar avatar,
    required bool onlyText,
    String? attachedImage,
  }) async {
    final String languageCode = await _settingsService.getLanguage() ?? 'fr';
    final String wrappedUserMessage =
        "${localized.currentDate} : ${DateTime.now().toLongLocalDateString(language: languageCode)}\n${localized.currentAvatarConfig} :\n{\n$avatar\n}\n${localized.userMessage} : \n'''$lastUserMessage'''";
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
      final ChatEntry newModelEntry = await _yofardevRepository.askYofardevAi(
        chat,
        userEntry.body,
        functionCallingEnabled: state.functionCallingEnabled,
      );
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
      await _chatHistoryService.updateChat(chatId: chat.id, updatedChat: chat);
      return newModelEntry;
    } catch (e) {
      AppLogger.error('Error sending text message', tag: 'ChatsCubit', error: e);
      emit(
        state.copyWith(status: ChatsStatus.error, errorMessage: e.toString()),
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
    await _chatHistoryService.updateAvatar(
      chat.id,
      chat.avatar.copyWith(background: bg),
    );
  }

  void updateAvatarOpenedChat(AvatarConfig avatarConfig) async {
    emit(state.copyWith(status: ChatsStatus.updating));
    final Chat chat = state.openedChat;
    final Avatar avatar = chat.avatar.copyWith(
      hat: avatarConfig.hat ?? chat.avatar.hat,
      top: avatarConfig.top ?? chat.avatar.top,
      background: avatarConfig.background ?? chat.avatar.background,
      glasses: avatarConfig.glasses ?? chat.avatar.glasses,
      specials: avatarConfig.specials ?? chat.avatar.specials,
      costume: avatarConfig.costume ?? chat.avatar.costume,
    );
    emit(
      state.copyWith(
        openedChat: chat.copyWith(avatar: avatar),
        status: ChatsStatus.success,
      ),
    );
    await _chatHistoryService.updateAvatar(chat.id, avatar);
  }
}
