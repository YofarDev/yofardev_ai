import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/avatar/domain/models/npc_intent.dart';
import 'package:yofardev_ai/features/avatar/domain/services/gull_flock.dart';

void main() {
  final DateTime t0 = DateTime(2026, 6, 1, 12);
  late GullFlock flock;

  DateTime at(double seconds) =>
      t0.add(Duration(microseconds: (seconds * 1e6).round()));

  NpcIntent eval(
    double seconds, {
    bool active = true,
    double rain = 0,
    bool reduceMotion = false,
    bool excited = false,
  }) => flock.evaluate(
    at(seconds),
    active: active,
    rain: rain,
    reduceMotion: reduceMotion,
    excited: excited,
  );

  setUp(() => flock = GullFlock());

  test('the constants are the ruled ones', () {
    expect(GullFlock.landLength, const Duration(milliseconds: 2500));
    expect(GullFlock.fleeLength, const Duration(milliseconds: 1500));
    expect(GullFlock.reactLength, const Duration(milliseconds: 600));
    expect(GullFlock.calmToLand, const Duration(seconds: 12));
    expect(GullFlock.rainAway, 0.5);
    expect(GullFlock.excitedArousal, 0.7);
  });

  test('they start away, off the right edge', () {
    expect(eval(0), NpcIntent.away);
    expect(eval(11.9), NpcIntent.away);
  });

  test('after 12 s of calm they land: move 1 -> 0 in 2.5 s, then idle', () {
    eval(0);
    NpcIntent landing = eval(12.0);
    expect(landing.npc, NpcState.move);
    expect(landing.npcX, closeTo(1, 1e-6));
    expect(landing.npcLook, GullFlock.landLook, reason: 'flying left');
    expect(GullFlock.landLook, -1);
    landing = eval(13.25);
    expect(landing.npc, NpcState.move);
    expect(landing.npcX, closeTo(0.5, 1e-6));
    expect(landing.npcLook, -1);
    final NpcIntent landed = eval(14.5);
    expect(landed, const NpcIntent(npc: NpcState.idle));
    expect(eval(60), const NpcIntent(npc: NpcState.idle));
  });

  test('the flight is monotone', () {
    eval(0);
    double last = 1.01;
    for (double s = 12; s <= 14.5; s += 0.1) {
      final NpcIntent i = eval(s);
      expect(i.npcX, lessThanOrEqualTo(last + 1e-9));
      last = i.npcX;
    }
  });

  test('a startle: react 0.6 s, fly off 0 -> 1 in 1.5 s, then away', () {
    eval(0);
    eval(15); // landed
    flock.startle(at(20));
    expect(eval(20), const NpcIntent(npc: NpcState.react));
    expect(eval(20.5), const NpcIntent(npc: NpcState.react));
    final NpcIntent fleeStart = eval(20.6);
    expect(fleeStart.npc, NpcState.move);
    expect(fleeStart.npcX, closeTo(0, 1e-6));
    expect(fleeStart.npcLook, GullFlock.flyOffLook, reason: 'flying right');
    expect(GullFlock.flyOffLook, 1);
    final NpcIntent mid = eval(21.35);
    expect(mid.npc, NpcState.move);
    expect(mid.npcX, closeTo(0.5, 1e-6));
    expect(eval(22.1), NpcIntent.away);
    expect(eval(25), NpcIntent.away);
  });

  test('they land again 12 s after the last disturbance', () {
    eval(0);
    eval(15);
    flock.startle(at(20));
    eval(20);
    expect(eval(31.9), NpcIntent.away);
    expect(eval(32.0).npc, NpcState.move);
    expect(eval(40), const NpcIntent(npc: NpcState.idle));
  });

  test('a startle while away only restarts the calm timer', () {
    eval(0);
    flock.startle(at(8));
    expect(eval(8), NpcIntent.away);
    expect(eval(15), NpcIntent.away, reason: '12 s from 8 is 20');
    expect(eval(20.0).npc, NpcState.move);
  });

  test('a startle while they land: straight back out from where they are', () {
    eval(0);
    eval(13.25); // x 0.5
    flock.startle(at(13.25));
    final NpcIntent out = eval(13.25);
    expect(out.npc, NpcState.move);
    expect(out.npcX, closeTo(0.5, 1e-6));
    expect(out.npcLook, GullFlock.flyOffLook);
    // half the way left: 0.75 s
    expect(eval(13.25 + 0.375).npcX, greaterThan(0.5));
    expect(eval(14.1), NpcIntent.away);
  });

  test('a startle at the very start of the landing just keeps them away', () {
    eval(0);
    eval(12.0);
    flock.startle(at(12.0));
    expect(eval(12.0), NpcIntent.away);
  });

  test('rain >= 0.5 keeps them away and chases them off the sand', () {
    eval(0);
    expect(eval(13, rain: 0.5), NpcIntent.away);
    expect(eval(60, rain: 0.9), NpcIntent.away);
    // the rain stops at 60: 12 s of calm from then
    expect(eval(60.1, rain: 0.2), NpcIntent.away);
    expect(eval(71.9, rain: 0.2), NpcIntent.away);
    expect(eval(72.2, rain: 0.2).npc, NpcState.move);
    expect(eval(80, rain: 0.2).npc, NpcState.idle);
    // rain starts: react, flee, away
    expect(eval(90, rain: 0.6), const NpcIntent(npc: NpcState.react));
    expect(eval(90.7, rain: 0.6).npc, NpcState.move);
    expect(eval(93, rain: 0.6), NpcIntent.away);
  });

  test('the calm is counted from when a long rain stops, not before', () {
    eval(0);
    expect(eval(1, rain: 0.9), NpcIntent.away);
    // nothing evaluated for a long while (no timer runs under rain)
    expect(eval(500, rain: 0.1), NpcIntent.away);
    expect(eval(511, rain: 0.1), NpcIntent.away);
    expect(eval(512.1, rain: 0.1).npc, NpcState.move);
  });

  test('light rain (< 0.5) is fine', () {
    eval(0);
    expect(eval(12.0, rain: 0.49).npc, NpcState.move);
  });

  test(
    'the avatar speaking with arousal >= 0.7 scares them and holds them off',
    () {
      eval(0);
      eval(15);
      expect(eval(20, excited: true), const NpcIntent(npc: NpcState.react));
      expect(eval(21, excited: true).npc, NpcState.move);
      expect(eval(40, excited: true), NpcIntent.away);
      // it ends at 41: calm from then
      expect(eval(41, excited: false), NpcIntent.away);
      expect(eval(52.9), NpcIntent.away);
      expect(eval(53.1).npc, NpcState.move);
    },
  );

  test('reduce motion: they appear and vanish, no flight', () {
    eval(0, reduceMotion: true);
    // a landing is a jump: away, then there
    expect(eval(12.0, reduceMotion: true), const NpcIntent(npc: NpcState.away));
    expect(eval(12.2, reduceMotion: true), const NpcIntent(npc: NpcState.away));
    expect(eval(12.5, reduceMotion: true), const NpcIntent(npc: NpcState.idle));
    // a startle: they are simply gone
    flock.startle(at(20));
    expect(eval(20, reduceMotion: true), NpcIntent.away);
    expect(eval(20.3, reduceMotion: true), NpcIntent.away);
  });

  test('reduce motion switched on mid-flight ends the flight', () {
    eval(0);
    expect(eval(13).npc, NpcState.move);
    expect(eval(13.1, reduceMotion: true), const NpcIntent(npc: NpcState.idle));
  });

  test('inactive (off the beach, low tier) means away and forgets', () {
    eval(0);
    eval(15);
    expect(eval(16, active: false), NpcIntent.away);
    // back on the beach: the calm timer starts over
    expect(eval(17), NpcIntent.away);
    expect(eval(28.9), NpcIntent.away);
    expect(eval(29.1).npc, NpcState.move);
  });

  test('a long gap crosses several phases in one evaluation', () {
    eval(0);
    eval(15);
    flock.startle(at(20));
    expect(eval(20), const NpcIntent(npc: NpcState.react));
    // the clock jumps 30 s: flee done, calm over, landed
    expect(eval(50), const NpcIntent(npc: NpcState.idle));
  });

  test('animating and nextChange tell the director when to wake', () {
    eval(0);
    expect(flock.animating, isFalse);
    expect(flock.nextChange, at(12));
    eval(13);
    expect(flock.animating, isTrue);
    expect(flock.nextChange, at(14.5));
    eval(15);
    expect(flock.animating, isFalse);
    expect(flock.nextChange, isNull);
    flock.startle(at(16));
    eval(16);
    expect(flock.animating, isFalse);
    expect(flock.nextChange, at(16.6));
    eval(17);
    expect(flock.animating, isTrue);
    eval(30, rain: 1);
    expect(flock.nextChange, isNull, reason: 'held away by rain');
  });
}
