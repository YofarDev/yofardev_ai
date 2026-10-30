import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/avatar_gesture.dart';
import '../../../../core/models/avatar_mood.dart';
import '../../../../core/models/avatar_scene.dart';
import '../../../../core/models/avatar_status_animation.dart';
import '../../../../core/models/performance/avatar_prop.dart';
import '../../../../core/models/performance/tablet_weather.dart';
import '../../domain/models/background_transition.dart';
import '../../domain/models/head_pose.dart';
import '../../domain/models/journey.dart';

export '../../../../core/models/avatar_status_animation.dart';
export '../../../../core/models/performance/tablet_weather.dart';
export '../../domain/models/background_transition.dart';
export '../../domain/models/head_pose.dart' show HeadTarget;
export '../../domain/models/journey.dart';

part 'avatar_state.freezed.dart';

enum AvatarStatus { initial, ready, loading }

@freezed
sealed class AvatarState with _$AvatarState {
  const AvatarState._();

  const factory AvatarState({
    @Default(AvatarStatus.initial) AvatarStatus status,
    @Default(AvatarStatusAnimation.initial)
    AvatarStatusAnimation statusAnimation,
    @Default(0.0) double baseOriginalWidth,
    @Default(0.0) double baseOriginalHeight,
    @Default(1.0) double scaleFactor,
    required Avatar avatar,
    required AvatarConfig avatarConfig,
    @Default(AvatarSpecials.onScreen) AvatarSpecials previousSpecialsState,
    @Default(BackgroundTransition.none)
    BackgroundTransition backgroundTransition,
    @Default(AvatarMood.neutral) AvatarMood mood,
    @Default(AvatarScene.defaultScene) AvatarScene scene,
    @Default((gesture: AvatarGesture.wave, seq: 0))
    ({AvatarGesture gesture, int seq}) gestureEvent,
    @Default((sceneEvent: SceneEvent.lightsOff, seq: 0))
    ({SceneEvent sceneEvent, int seq}) sceneEvent,
    @Default(AvatarSpecials.onScreen) AvatarSpecials presence,

    /// Where the head should look, from the director's gaze.
    @Default(HeadTarget.zero) HeadTarget headTarget,

    /// The prop held, from the director's intent (written to Rive `prop`).
    @Default(AvatarProp.none) AvatarProp prop,

    /// The scene journey under way (M7), null when none.
    JourneyState? journey,

    /// The scene the stage should decode ahead of a journey's cut.
    AvatarScene? preloadScene,

    /// The avatar holds the storybook jacket (contract v11 `jacket`): true
    /// from a door journey's grab contact to its hang contact.
    @Default(false) bool jacket,

    /// The jacket on the journey door's peg (`JourneyVM.jacket`, 0..1). It
    /// flips with [jacket] in the same state, so one jacket always shows.
    @Default(0.0) double journeyJacket,

    /// The tablet's weather card, from the director's intent (v11).
    @Default(TabletWeather.none) TabletWeather tabletWeather,
    @Default(0) int tabletTemp,
  }) = _AvatarState;
}
