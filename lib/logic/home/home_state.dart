part of 'home_cubit.dart';

class HomeState {
  final bool isInitialized;
  final bool isPlayingWaitingTts;

  const HomeState({
    this.isInitialized = false,
    this.isPlayingWaitingTts = false,
  });

  HomeState copyWith({bool? isInitialized, bool? isPlayingWaitingTts}) {
    return HomeState(
      isInitialized: isInitialized ?? this.isInitialized,
      isPlayingWaitingTts: isPlayingWaitingTts ?? this.isPlayingWaitingTts,
    );
  }
}
