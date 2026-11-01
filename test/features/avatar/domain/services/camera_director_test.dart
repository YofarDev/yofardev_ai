import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/core/models/talking_phase.dart';
import 'package:yofardev_ai/features/avatar/domain/services/camera_director.dart';

/// Runs [body] in a fake-async zone with a director and its emissions.
void _run(
  void Function(
    FakeAsync async,
    CameraDirector director,
    List<CameraShot> shots,
  )
  body,
) {
  fakeAsync((FakeAsync async) {
    final DateTime base = DateTime(2026, 10, 30, 12);
    final CameraDirector director = CameraDirector(
      now: () => base.add(async.elapsed),
    );
    final List<CameraShot> shots = <CameraShot>[];
    director.shot.addListener(() => shots.add(director.shot.value));
    body(async, director, shots);
    director.dispose();
  });
}

void _expectShot(
  CameraShot actual,
  Shot shot,
  CameraMove move, {
  int? ms,
  double? creep,
}) {
  expect(actual.shot, shot);
  expect(actual.move, move);
  if (ms != null) {
    expect(actual.duration, Duration(milliseconds: ms));
  }
  if (creep != null) {
    expect(actual.creep, closeTo(creep, 1e-9));
  }
}

const Duration _ms2499 = Duration(milliseconds: 2499);
const Duration _ms1 = Duration(milliseconds: 1);

void main() {
  group('CameraShot', () {
    test('initial is wide, cut, serial 0', () {
      expect(CameraShot.initial.shot, Shot.wide);
      expect(CameraShot.initial.move, CameraMove.cut);
      expect(CameraShot.initial.duration, Duration.zero);
      expect(CameraShot.initial.creep, 0);
      expect(CameraShot.initial.serial, 0);
    });

    test('equality covers every field, including the serial', () {
      const CameraShot a = CameraShot(
        shot: Shot.medium,
        move: CameraMove.ease,
        duration: Duration(seconds: 1),
        creep: 0.04,
        creepDuration: Duration(seconds: 4),
        serial: 3,
      );
      const CameraShot same = CameraShot(
        shot: Shot.medium,
        move: CameraMove.ease,
        duration: Duration(seconds: 1),
        creep: 0.04,
        creepDuration: Duration(seconds: 4),
        serial: 3,
      );
      const CameraShot other = CameraShot(
        shot: Shot.medium,
        move: CameraMove.ease,
        duration: Duration(seconds: 1),
        creep: 0.04,
        creepDuration: Duration(seconds: 4),
        serial: 4,
      );
      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect(a, isNot(other));
    });
  });

  group('CameraDirector.nominalZoom', () {
    test('wide 1.0, medium 1.5, closeUp 2.2, propInsert 2.0', () {
      expect(CameraDirector.nominalZoom(Shot.wide), 1.0);
      expect(CameraDirector.nominalZoom(Shot.medium), 1.5);
      expect(CameraDirector.nominalZoom(Shot.closeUp), 2.2);
      expect(CameraDirector.nominalZoom(Shot.propInsert), 2.0);
    });
  });

  group('CameraDirector', () {
    test('starts on the initial shot and emits nothing', () {
      _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
        expect(d.shot.value, CameraShot.initial);
        expect(shots, isEmpty);
      });
    });

    group('rule 1: reduce motion', () {
      test('locks medium with one cut and then emits nothing', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setReduceMotion(true);
          expect(shots, hasLength(1));
          _expectShot(shots.single, Shot.medium, CameraMove.cut);
          expect(shots.single.duration, Duration.zero);

          d.setReduceMotion(true);
          d.setJourney(true);
          d.onSceneEvent();
          d.setProp(AvatarProp.tablet);
          d.setPhase(TalkingPhase.waiting);
          d.setComposing(true);
          d.setSpeaking(true);
          d.onSentence('Really?', intensity: 0.9);
          d.setSpeaking(false);
          async.elapse(const Duration(seconds: 30));
          expect(shots, hasLength(1));
        });
      });

      test('everything is still tracked: the right shot resumes', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setReduceMotion(true);
          d.setProp(AvatarProp.tablet);
          expect(shots, hasLength(1));
          d.setReduceMotion(false);
          expect(shots, hasLength(2));
          _expectShot(shots.last, Shot.propInsert, CameraMove.ease, ms: 700);
        });
      });

      test('turning it off with nothing else going on pulls back to wide', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setReduceMotion(true);
          d.setReduceMotion(false);
          expect(shots, hasLength(1));
          async.elapse(_ms2499);
          expect(shots, hasLength(1));
          async.elapse(_ms1);
          expect(shots, hasLength(2));
          _expectShot(shots.last, Shot.wide, CameraMove.ease, ms: 1500);
        });
      });

      test('a medium already on screen is not cut again', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setComposing(true);
          expect(shots, hasLength(1));
          d.setReduceMotion(true);
          expect(shots, hasLength(1));
        });
      });
    });

    group('rule 2: journey', () {
      test('pulls back to wide in 600 ms and holds until it ends', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setComposing(true);
          d.setJourney(true);
          expect(shots, hasLength(2));
          _expectShot(shots.last, Shot.wide, CameraMove.ease, ms: 600);

          d.setProp(AvatarProp.newspaper);
          d.setPhase(TalkingPhase.generating);
          async.elapse(const Duration(seconds: 20));
          expect(shots, hasLength(2));

          d.setJourney(false);
          expect(shots, hasLength(3));
          _expectShot(shots.last, Shot.propInsert, CameraMove.ease, ms: 700);
        });
      });

      test('a sentence during a journey frames nothing', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setJourney(true);
          d.setSpeaking(true);
          d.onSentence('Hello there.', intensity: 0);
          expect(shots, isEmpty);
          expect(d.shot.value.shot, Shot.wide);
        });
      });
    });

    group('rule 3: scene event', () {
      test('wide in 600 ms, held 2.5 s, then the next rule applies', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setComposing(true);
          d.onSceneEvent();
          expect(shots, hasLength(2));
          _expectShot(shots.last, Shot.wide, CameraMove.ease, ms: 600);

          async.elapse(_ms2499);
          expect(shots, hasLength(2));
          async.elapse(_ms1);
          expect(shots, hasLength(3));
          _expectShot(shots.last, Shot.medium, CameraMove.ease, ms: 1200);
        });
      });

      test('holds the camera against a prop until it ends', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setComposing(true);
          d.onSceneEvent();
          d.setProp(AvatarProp.tablet);
          expect(shots, hasLength(2));
          async.elapse(_ms2499);
          expect(shots, hasLength(2));
          async.elapse(_ms1);
          _expectShot(shots.last, Shot.propInsert, CameraMove.ease, ms: 700);
        });
      });

      test('a second event restarts the 2.5 s hold', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setComposing(true);
          d.onSceneEvent();
          async.elapse(const Duration(seconds: 2));
          d.onSceneEvent();
          async.elapse(const Duration(seconds: 2));
          expect(shots, hasLength(2));
          async.elapse(const Duration(milliseconds: 500));
          expect(shots, hasLength(3));
          expect(shots.last.shot, Shot.medium);
        });
      });

      test('journey wins over a scene event', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setJourney(true);
          d.onSceneEvent();
          async.elapse(const Duration(seconds: 5));
          expect(shots, hasLength(0));
          d.setComposing(true);
          expect(shots, isEmpty);
          d.setJourney(false);
          expect(shots, hasLength(1));
          _expectShot(shots.last, Shot.medium, CameraMove.ease, ms: 1200);
        });
      });

      test('pulling back while speaking is an ease, not a cut', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setSpeaking(true);
          d.onSentence('First.', intensity: 0);
          expect(shots.last.move, CameraMove.cut);
          d.onSceneEvent();
          _expectShot(shots.last, Shot.wide, CameraMove.ease, ms: 600);
        });
      });
    });

    group('rule 4: prop', () {
      test('pushes to propInsert in 700 ms', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setProp(AvatarProp.tablet);
          expect(shots, hasLength(1));
          _expectShot(shots.single, Shot.propInsert, CameraMove.ease, ms: 700);
        });
      });

      test('wins over composing and thinking', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setProp(AvatarProp.newspaper);
          d.setComposing(true);
          d.setPhase(TalkingPhase.waiting);
          expect(shots, hasLength(1));
          expect(shots.single.shot, Shot.propInsert);
        });
      });

      test('putting it away resolves to the next rule', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setProp(AvatarProp.tablet);
          d.setComposing(true);
          d.setProp(AvatarProp.none);
          expect(shots, hasLength(2));
          _expectShot(shots.last, Shot.medium, CameraMove.ease, ms: 1200);
        });
      });

      test('sentences are counted but frame nothing while a prop is out', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setProp(AvatarProp.tablet);
          d.setSpeaking(true);
          d.onSentence('One.', intensity: 0);
          d.onSentence('Two?', intensity: 1);
          expect(shots, hasLength(1));
          expect(shots.single.shot, Shot.propInsert);
        });
      });

      test('after the prop leaves mid-reply the next sentence cuts', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setProp(AvatarProp.tablet);
          d.setSpeaking(true);
          d.setProp(AvatarProp.none);
          expect(shots, hasLength(1));
          d.onSentence('Done?', intensity: 0);
          // Sentence 1 of the reply: medium, cut (not held on the insert).
          expect(shots, hasLength(2));
          _expectShot(shots.last, Shot.medium, CameraMove.cut);
          // Close-up (2.2) vs insert (2.0) is under 20 %, yet it must cut.
          d.setProp(AvatarProp.tablet);
          d.setProp(AvatarProp.none);
          d.onSentence('Wow?', intensity: 0);
          _expectShot(shots.last, Shot.closeUp, CameraMove.cut);
        });
      });
    });

    group('rule 5: speaking', () {
      test(
        'the first sentence of a reply is a medium cut, even a question',
        () {
          _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
            d.setSpeaking(true);
            expect(shots, isEmpty);
            d.onSentence('Really?', intensity: 0.9);
            expect(shots, hasLength(1));
            _expectShot(
              shots.single,
              Shot.medium,
              CameraMove.cut,
              creep: CameraDirector.creepPerSentence,
            );
            expect(shots.single.duration, Duration.zero);
            expect(shots.single.creepDuration, const Duration(seconds: 4));
          });
        },
      );

      test('a question earns a close-up cut; trailing spaces are ignored', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setSpeaking(true);
          d.onSentence('Hello.', intensity: 0);
          d.onSentence('How are you?  ', intensity: 0);
          _expectShot(shots.last, Shot.closeUp, CameraMove.cut);
        });
      });

      test('intensity 0.6 earns a close-up, 0.59 does not', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setSpeaking(true);
          d.onSentence('Hello.', intensity: 0);
          d.onSentence('Fine.', intensity: 0.59);
          // Medium again: held (same shot), not a cut.
          expect(shots.last.shot, Shot.medium);
          expect(shots.last.move, CameraMove.ease);
          d.onSentence('Wow.', intensity: 0.6);
          _expectShot(shots.last, Shot.closeUp, CameraMove.cut);
        });
      });

      test('every third sentence is a close-up: 3rd and 6th', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setSpeaking(true);
          final List<Shot> kinds = <Shot>[];
          final List<CameraMove> moves = <CameraMove>[];
          for (int i = 1; i <= 6; i++) {
            d.onSentence('Sentence $i.', intensity: 0);
            kinds.add(d.shot.value.shot);
            moves.add(d.shot.value.move);
          }
          expect(kinds, <Shot>[
            Shot.medium,
            Shot.medium,
            Shot.closeUp,
            Shot.medium,
            Shot.medium,
            Shot.closeUp,
          ]);
          // 1: cut, 2: held (ease), 3: cut, 4: cut, 5: held, 6: cut.
          expect(moves, <CameraMove>[
            CameraMove.cut,
            CameraMove.ease,
            CameraMove.cut,
            CameraMove.cut,
            CameraMove.ease,
            CameraMove.cut,
          ]);
        });
      });

      test('the sentence count restarts with each reply', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setSpeaking(true);
          d.onSentence('One.', intensity: 0);
          d.onSentence('Two.', intensity: 0);
          d.setSpeaking(false);
          d.setSpeaking(true);
          // Sentence 1 of the new reply: medium, not the 3rd of the old one.
          d.onSentence('Three?', intensity: 1);
          expect(d.shot.value.shot, Shot.medium);
        });
      });

      test('setSpeaking(true) twice does not restart the count', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setSpeaking(true);
          d.onSentence('One.', intensity: 0);
          d.setSpeaking(true);
          d.onSentence('Two?', intensity: 0);
          expect(d.shot.value.shot, Shot.closeUp);
        });
      });

      test('a zoom change under 20 % holds the shot and only adds creep', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setSpeaking(true);
          d.onSentence('One.', intensity: 0);
          expect(shots, hasLength(1));
          d.onSentence('Two.', intensity: 0);
          expect(shots, hasLength(2));
          _expectShot(shots.last, Shot.medium, CameraMove.ease, creep: 0.08);
          expect(shots.last.serial, shots.first.serial + 1);
        });
      });

      test('a big zoom change (medium to close-up and back) cuts', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setSpeaking(true);
          d.onSentence('One.', intensity: 0);
          d.onSentence('Two?', intensity: 0);
          _expectShot(shots.last, Shot.closeUp, CameraMove.cut);
          d.onSentence('Three.', intensity: 0); // 3rd sentence: close-up, held
          expect(shots.last.shot, Shot.closeUp);
          d.onSentence('Four.', intensity: 0);
          _expectShot(shots.last, Shot.medium, CameraMove.cut);
        });
      });

      test('creep accumulates +0.04 a sentence and caps at +0.10', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setSpeaking(true);
          d.onSentence('One.', intensity: 0);
          expect(d.shot.value.creep, closeTo(0.04, 1e-9));
          d.onSentence('Two.', intensity: 0);
          expect(d.shot.value.creep, closeTo(0.08, 1e-9));
          // 3rd sentence is a close-up cut, so go on with a held pair.
          d.onSentence('Three.', intensity: 0);
          d.onSentence('Four.', intensity: 0);
          d.onSentence('Five.', intensity: 0); // held on medium after the cut
          d.onSentence('Six.', intensity: 0); // close-up cut
          expect(d.shot.value.move, CameraMove.cut);
        });
      });

      test('the cap is 0.10 and nothing is emitted past it', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setSpeaking(true);
          // Intensity 0 and no question: sentences 1, 2 medium (held), but
          // the 3rd is a close-up. Use setSpeaking restarts to keep medium.
          d.onSentence('One.', intensity: 0);
          d.onSentence('Two.', intensity: 0);
          expect(d.shot.value.creep, closeTo(0.08, 1e-9));
          // Skip the 3rd: reach the cap on a medium by a new reply.
          d.setSpeaking(false);
          d.setSpeaking(true);
          d.onSentence('Alpha.', intensity: 0); // held, creep 0.08 + .04 -> cap
          expect(d.shot.value.creep, closeTo(0.10, 1e-9));
          final int count = shots.length;
          d.onSentence('Beta.', intensity: 0);
          expect(shots, hasLength(count));
          expect(d.shot.value.creep, closeTo(0.10, 1e-9));
        });
      });

      test('a cut resets the creep accumulator', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setSpeaking(true);
          d.onSentence('One.', intensity: 0);
          d.onSentence('Two.', intensity: 0); // creep 0.08
          d.onSentence('Three.', intensity: 0); // close-up cut: 0.04
          _expectShot(shots.last, Shot.closeUp, CameraMove.cut, creep: 0.04);
          d.onSentence('Four.', intensity: 0); // medium cut: 0.04
          expect(shots.last.creep, closeTo(0.04, 1e-9));
          d.onSentence('Five.', intensity: 0); // held: 0.08
          expect(shots.last.creep, closeTo(0.08, 1e-9));
        });
      });

      test('an eased move resets the creep accumulator', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setSpeaking(true);
          d.onSentence('One.', intensity: 0);
          d.onSentence('Two.', intensity: 0);
          d.onSceneEvent();
          async.elapse(CameraDirector.sceneHold);
          // Wide now; the next sentence (the 3rd, a close-up) cuts with a
          // fresh 0.04, not 0.08 + 0.04.
          d.onSentence('Three.', intensity: 0);
          _expectShot(shots.last, Shot.closeUp, CameraMove.cut, creep: 0.04);
        });
      });

      test('stopping speech changes nothing at once, then pulls back', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setSpeaking(true);
          d.onSentence('One.', intensity: 0);
          d.setSpeaking(false);
          expect(shots, hasLength(1));
          async.elapse(_ms2499);
          expect(shots, hasLength(1));
          async.elapse(_ms1);
          _expectShot(shots.last, Shot.wide, CameraMove.ease, ms: 1500);
        });
      });

      test('rules 6 and 7 do not apply while speaking', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setSpeaking(true);
          d.onSentence('One.', intensity: 0);
          d.setComposing(true);
          d.setPhase(TalkingPhase.generating);
          async.elapse(const Duration(seconds: 10));
          expect(shots, hasLength(1));
        });
      });

      test('the idle timer does not pull back mid-reply', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setComposing(true);
          d.setComposing(false); // idle timer starts
          d.setSpeaking(true);
          async.elapse(const Duration(seconds: 10));
          expect(shots, hasLength(1));
          expect(shots.single.shot, Shot.medium);
        });
      });
    });

    group('rule 6: composing and thinking', () {
      test('composing pushes to medium in 1200 ms', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setComposing(true);
          expect(shots, hasLength(1));
          _expectShot(shots.single, Shot.medium, CameraMove.ease, ms: 1200);
        });
      });

      test('waiting and generating push to medium, idle and error do not', () {
        for (final TalkingPhase phase in <TalkingPhase>[
          TalkingPhase.waiting,
          TalkingPhase.generating,
        ]) {
          _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
            d.setPhase(phase);
            expect(shots, hasLength(1), reason: phase.name);
            _expectShot(shots.single, Shot.medium, CameraMove.ease, ms: 1200);
          });
        }
        for (final TalkingPhase phase in <TalkingPhase>[
          TalkingPhase.idle,
          TalkingPhase.speaking,
          TalkingPhase.error,
        ]) {
          _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
            d.setPhase(phase);
            expect(shots, isEmpty, reason: phase.name);
          });
        }
      });

      test('stays medium while either condition holds', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setComposing(true);
          d.setPhase(TalkingPhase.waiting);
          d.setComposing(false);
          async.elapse(const Duration(seconds: 10));
          expect(shots, hasLength(1));
          d.setPhase(TalkingPhase.idle);
          async.elapse(CameraDirector.idleDelay);
          expect(shots, hasLength(2));
          expect(shots.last.shot, Shot.wide);
        });
      });
    });

    group('rule 7: idle pull-back', () {
      test('wide, eased 1500 ms, after 2.5 s of nothing', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setComposing(true);
          d.setComposing(false);
          async.elapse(_ms2499);
          expect(shots, hasLength(1));
          async.elapse(_ms1);
          expect(shots, hasLength(2));
          _expectShot(shots.last, Shot.wide, CameraMove.ease, ms: 1500);
        });
      });

      test('is cancelled when something else takes over', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setComposing(true);
          d.setComposing(false);
          async.elapse(const Duration(seconds: 2));
          d.setComposing(true);
          async.elapse(const Duration(seconds: 10));
          expect(shots, hasLength(1));
        });
      });

      test('a redundant input does not restart the delay', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setComposing(true);
          d.setComposing(false);
          async.elapse(const Duration(seconds: 2));
          d.setProp(AvatarProp.none);
          d.setPhase(TalkingPhase.idle);
          async.elapse(const Duration(milliseconds: 500));
          expect(shots, hasLength(2));
        });
      });

      test('nothing is emitted when already wide', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setProp(AvatarProp.none);
          d.setPhase(TalkingPhase.idle);
          d.setComposing(false);
          d.setSpeaking(false);
          async.elapse(const Duration(seconds: 30));
          expect(shots, isEmpty);
          expect(async.pendingTimers, isEmpty);
        });
      });

      test('follows the prop being put away', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setProp(AvatarProp.tablet);
          d.setProp(AvatarProp.none);
          expect(shots, hasLength(1));
          async.elapse(CameraDirector.idleDelay);
          expect(shots, hasLength(2));
          _expectShot(shots.last, Shot.wide, CameraMove.ease, ms: 1500);
        });
      });
    });

    group('invariants', () {
      test('cuts only come from onSentence (reduce motion aside)', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setComposing(true);
          d.setPhase(TalkingPhase.generating);
          d.setProp(AvatarProp.tablet);
          d.setProp(AvatarProp.none);
          d.onSceneEvent();
          async.elapse(const Duration(seconds: 3));
          d.setJourney(true);
          d.setJourney(false);
          d.setSpeaking(true);
          d.setSpeaking(false);
          d.setComposing(false);
          d.setPhase(TalkingPhase.idle);
          async.elapse(const Duration(seconds: 10));
          expect(shots, isNotEmpty);
          expect(
            shots.where((CameraShot s) => s.move == CameraMove.cut),
            isEmpty,
          );
        });
      });

      test('no duplicate emissions for repeated inputs', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setComposing(true);
          d.setComposing(true);
          d.setPhase(TalkingPhase.waiting);
          d.setPhase(TalkingPhase.generating);
          expect(shots, hasLength(1));
          d.setProp(AvatarProp.tablet);
          d.setProp(AvatarProp.newspaper);
          expect(shots, hasLength(2));
          d.setJourney(true);
          d.setJourney(true);
          d.onSceneEvent();
          d.onSceneEvent();
          expect(shots, hasLength(3));
        });
      });

      test('the serial increments on every command', () {
        _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
          d.setComposing(true);
          d.setProp(AvatarProp.tablet);
          d.setProp(AvatarProp.none);
          d.setSpeaking(true);
          d.onSentence('One.', intensity: 0);
          d.onSentence('Two.', intensity: 0);
          for (int i = 0; i < shots.length; i++) {
            expect(shots[i].serial, i + 1);
          }
        });
      });

      test('dispose cancels the timers', () {
        fakeAsync((FakeAsync async) {
          final CameraDirector d = CameraDirector(now: DateTime.now);
          d.setComposing(true);
          d.onSceneEvent();
          d.setComposing(false);
          expect(async.pendingTimers, isNotEmpty);
          d.dispose();
          expect(async.pendingTimers, isEmpty);
        });
      });

      test('a disposed director ignores late inputs', () {
        fakeAsync((FakeAsync async) {
          final CameraDirector d = CameraDirector(now: DateTime.now);
          d.dispose();
          d.setComposing(true);
          d.onSentence('Late.', intensity: 1);
          expect(async.pendingTimers, isEmpty);
        });
      });
    });
  });

  group('quality tier (M11 ruling 13)', () {
    test('low: sentences cut with no creep and a held sentence adds none', () {
      _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
        d.setTier(QualityTier.low);
        d.setSpeaking(true);
        d.onSentence('One.', intensity: 0);
        expect(shots, hasLength(1));
        _expectShot(shots.single, Shot.medium, CameraMove.cut, creep: 0);
        expect(shots.single.creepDuration, Duration.zero);
        d.onSentence('Two.', intensity: 0);
        expect(shots, hasLength(1));
        d.onSentence('Three?', intensity: 0);
        _expectShot(shots.last, Shot.closeUp, CameraMove.cut, creep: 0);
      });
    });

    test('high keeps the push-in', () {
      _run((FakeAsync async, CameraDirector d, List<CameraShot> shots) {
        d.setTier(QualityTier.high);
        d.setSpeaking(true);
        d.onSentence('One.', intensity: 0);
        d.onSentence('Two.', intensity: 0);
        _expectShot(shots.last, Shot.medium, CameraMove.ease, creep: 0.08);
      });
    });
  });
}
