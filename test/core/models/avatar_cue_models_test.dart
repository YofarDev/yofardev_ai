import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_cue.dart';
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';

/// The shared v4 enums must name-match the Rive contract exactly: the cue
/// syntax, the prompts and the Rive view-model binding all go through
/// `enum.name`, so a typo here would silently target a property the `.riv`
/// files don't have.
void main() {
  group('contract name parity with avatar_rive_contract.dart', () {
    test('AvatarMood values match the contract mood list in order', () {
      expect(
        AvatarMood.values.map((AvatarMood m) => m.name).toList(),
        AvatarRiveContract.moodValues,
      );
    });

    test('AvatarGesture values match the contract gestureId list in order', () {
      expect(
        AvatarGesture.values.map((AvatarGesture g) => g.name).toList(),
        AvatarRiveContract.gestureIdValues,
      );
    });

    test('AvatarScene values match the contract scene ids in order', () {
      expect(
        AvatarScene.values.map((AvatarScene s) => s.name).toList(),
        AvatarRiveContract.sceneIds,
      );
    });

    test('SceneEvent values cover every scene eventId exactly once', () {
      final Set<String> allEventNames = AvatarRiveContract.sceneEvents.values
          .expand((List<String> events) => events)
          .toSet();
      expect(
        SceneEvent.values.map((SceneEvent e) => e.name).toSet(),
        allEventNames,
      );
      expect(
        SceneEvent.values.map((SceneEvent e) => e.name).toList(),
        SceneEvent.values.map((SceneEvent e) => e.name).toList(),
      );
      // Enum names are unique by construction; assert no eventId was folded
      // away: the union of the per-scene lists must be fully representable.
      expect(SceneEvent.values.length, allEventNames.length);
    });

    test('every scene maps to exactly its contract eventId values', () {
      AvatarRiveContract.sceneEvents.forEach((
        String sceneId,
        List<String> events,
      ) {
        final AvatarScene scene = AvatarScene.values.byName(sceneId);
        expect(
          scene.allowedEvents.map((SceneEvent e) => e.name).toList(),
          events,
        );
      });
    });
  });

  group('AvatarScene', () {
    test('defaultScene is livingRoom', () {
      expect(AvatarScene.defaultScene, AvatarScene.livingRoom);
    });

    test('rain is valid for both campfire and beach', () {
      expect(
        AvatarScene.campfire.allowedEvents.contains(SceneEvent.rain),
        isTrue,
      );
      expect(AvatarScene.beach.allowedEvents.contains(SceneEvent.rain), isTrue);
    });

    test('the shared events are valid in each scene that lists them (M9)', () {
      for (final AvatarScene scene in <AvatarScene>[
        AvatarScene.campfire,
        AvatarScene.beach,
        AvatarScene.cafe,
      ]) {
        expect(scene.allowedEvents, contains(SceneEvent.rain));
      }
      expect(
        AvatarScene.rooftop.allowedEvents,
        contains(SceneEvent.shootingStar),
      );
      expect(AvatarScene.mountainHut.allowedEvents, contains(SceneEvent.flare));
      expect(AvatarScene.mountainHut.allowedEvents, contains(SceneEvent.bell));
      // the hut snows: it has no rain event
      expect(
        AvatarScene.mountainHut.allowedEvents,
        isNot(contains(SceneEvent.rain)),
      );
      expect(AvatarScene.cafe.allowedEvents, isNot(contains(SceneEvent.bell)));
    });

    test('the v14 scenes: rain everywhere, their own events nowhere else '
        '(M11)', () {
      const Map<AvatarScene, List<SceneEvent>> own =
          <AvatarScene, List<SceneEvent>>{
            AvatarScene.forestCabin: <SceneEvent>[
              SceneEvent.gust,
              SceneEvent.fireflies,
              SceneEvent.lanternFlicker,
            ],
            AvatarScene.trainCompartment: <SceneEvent>[
              SceneEvent.tunnel,
              SceneEvent.whistle,
              SceneEvent.station,
            ],
            AvatarScene.library: <SceneEvent>[
              SceneEvent.lightning,
              SceneEvent.bookFlutter,
              SceneEvent.clockChime,
            ],
          };
      own.forEach((AvatarScene scene, List<SceneEvent> events) {
        expect(scene.allowedEvents, contains(SceneEvent.rain));
        expect(scene.allowedEvents, containsAll(events));
        for (final AvatarScene other in AvatarScene.values) {
          if (other == scene) {
            continue;
          }
          for (final SceneEvent event in events) {
            expect(
              other.allowedEvents,
              isNot(contains(event)),
              reason: '${other.name} ${event.name}',
            );
          }
        }
      });
    });

    test('every scene is a diorama (it reads the parallax numbers)', () {
      for (final AvatarScene scene in AvatarScene.values) {
        expect(scene.isDiorama, isTrue, reason: scene.name);
      }
    });

    test('a scene does not accept another scene’s events', () {
      expect(
        AvatarScene.livingRoom.allowedEvents.contains(SceneEvent.bigWave),
        isFalse,
      );
    });
  });

  group('AvatarCue', () {
    test('gesture cue carries its gesture', () {
      const AvatarCue cue = AvatarCue.gesture(AvatarGesture.wave);
      expect(
        cue.when(gesture: (AvatarGesture g) => g.name, sceneEvent: (_) => ''),
        'wave',
      );
    });

    test('scene event cue carries its event', () {
      const AvatarCue cue = AvatarCue.sceneEvent(SceneEvent.tvOn);
      expect(
        cue.when(gesture: (_) => '', sceneEvent: (SceneEvent e) => e.name),
        'tvOn',
      );
    });
  });
}
