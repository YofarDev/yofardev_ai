import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_state.freezed.dart';

@freezed
sealed class HomeState with _$HomeState {
  const factory HomeState({
    @Default(false) bool isInitialized,
    @Default(false) bool isFading,
    @Default(false) bool isPlayingWaitingLoop,
  }) = _HomeState;
}
