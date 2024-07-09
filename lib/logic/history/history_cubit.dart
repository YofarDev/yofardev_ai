import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/chat_entry.dart';
import '../../models/chat.dart';
import '../../services/chat_history_service.dart';
import '../../services/llm_service.dart';

part 'history_state.dart';

class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit() : super(const HistoryState());

  void fetchHistory() async {
    emit(state.copyWith(status: HistoryStatus.loading));
    final List<Chat> history =
        (await ChatHistoryService().getHistoryList()).reversed.toList();
    emit(state.copyWith(status: HistoryStatus.success, history: history));
  }

  void deleteChat(String id) async {
    emit(state.copyWith(status: HistoryStatus.updating));
    await ChatHistoryService().deleteChat(id);
    final List<Chat> history = state.history;
    history.removeWhere((Chat element) => element.id == id);
    emit(state.copyWith(history: history, status: HistoryStatus.success));
  }

  void setCurrentChat(Chat history) {
    emit(state.copyWith(currentChat: history.entries));
  }

  void onTextPromptSubmitted(String prompt) async {
    final List<ChatEntry> chat = state.currentChat;
    chat.add(
      ChatEntry(text: prompt, isFromUser: true, timestamp: DateTime.now()),
    );
    emit(
      state.copyWith(
        currentChat: <ChatEntry>[...chat],
        status: HistoryStatus.updating,
      ),
    );
    final Map<String, dynamic> responseMap =
        await LlmService().askYofardevAi(prompt);
    final String answerText = responseMap['text'] as String? ?? '';
    chat.add(
      ChatEntry(
        text: answerText,
        isFromUser: false,
        timestamp: DateTime.now(),
      ),
    );
    emit(
      state.copyWith(
        currentChat: <ChatEntry>[...chat],
        status: HistoryStatus.success,
      ),
    );
  }
}
