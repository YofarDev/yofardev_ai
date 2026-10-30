import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/avatar/domain/models/npc_intent.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/scene_npc_writer.dart';

void main() {
  late List<String> writes;

  void setEnum(String name, List<String> values, String value) {
    expect(values, AvatarRiveContract.npcValues);
    writes.add('$name=$value');
  }

  void setNumber(String name, double value) => writes.add('$name=$value');

  setUp(() => writes = <String>[]);

  test('the NPC enum matches the contract in order', () {
    expect(
      NpcState.values.map((NpcState s) => s.name).toList(),
      AvatarRiveContract.npcValues,
    );
  });

  test('writes npc, npcX and npcLook, then only what changed', () {
    final SceneNpcWriter writer = SceneNpcWriter(
      setEnum: setEnum,
      setNumber: setNumber,
    );
    writer.write(NpcIntent.rest);
    expect(writes, <String>['npc=rest', 'npcX=0.0', 'npcLook=0.0']);
    writer.write(NpcIntent.rest);
    writer.write(const NpcIntent(npcX: 0.0005));
    expect(writes, hasLength(3));
    writer.write(const NpcIntent(npc: NpcState.move, npcX: 0.4));
    expect(writes.sublist(3), <String>['npc=move', 'npcX=0.4']);
    writer.write(const NpcIntent(npc: NpcState.notice, npcX: 3, npcLook: -4));
    expect(writes.sublist(5), <String>[
      'npc=notice',
      'npcX=1.0',
      'npcLook=-1.0',
    ]);
  });

  test(
    'the follower writes the intent to each fresh file; an override wins',
    () {
      final ValueNotifier<NpcIntent> source = ValueNotifier<NpcIntent>(
        const NpcIntent(npc: NpcState.idle),
      );
      addTearDown(source.dispose);
      final SceneNpcFollower follower = SceneNpcFollower();
      addTearDown(follower.dispose);
      follower.follow(source);
      follower.load(setEnum, setNumber);
      expect(writes, <String>['npc=idle', 'npcX=0.0', 'npcLook=0.0']);
      source.value = const NpcIntent(npc: NpcState.move, npcX: 0.5);
      expect(writes.sublist(3), <String>['npc=move', 'npcX=0.5']);
      follower.follow(
        source,
        override: const NpcIntent(npc: NpcState.react, npcLook: 0.5),
      );
      expect(writes.sublist(5), <String>[
        'npc=react',
        'npcX=0.0',
        'npcLook=0.5',
      ]);
      source.value = const NpcIntent(npc: NpcState.away);
      expect(writes, hasLength(8));
      follower.unload();
      follower.follow(source);
      follower.load(setEnum, setNumber);
      expect(writes.sublist(8), <String>[
        'npc=away',
        'npcX=0.0',
        'npcLook=0.0',
      ]);
    },
  );

  test('without a source the NPC rests', () {
    final SceneNpcFollower follower = SceneNpcFollower();
    follower.load(setEnum, setNumber);
    expect(writes, <String>['npc=rest', 'npcX=0.0', 'npcLook=0.0']);
    follower.dispose();
  });

  group('the second slot (npc2, the gulls)', () {
    test('the property names are the contract v12 ones', () {
      expect(AvatarRiveContract.scenePropNpc2, 'npc2');
      expect(AvatarRiveContract.scenePropNpc2X, 'npc2X');
      expect(AvatarRiveContract.scenePropNpc2Look, 'npc2Look');
    });

    test('the writer writes npc2* beside npc*, each slot on its own', () {
      final SceneNpcWriter writer = SceneNpcWriter(
        setEnum: setEnum,
        setNumber: setNumber,
      );
      writer.write(NpcIntent.rest, second: NpcIntent.away);
      expect(writes, <String>[
        'npc=rest',
        'npcX=0.0',
        'npcLook=0.0',
        'npc2=away',
        'npc2X=1.0',
        'npc2Look=0.0',
      ]);
      writes.clear();
      // only the gulls move: only npc2* is written
      writer.write(
        NpcIntent.rest,
        second: const NpcIntent(npc: NpcState.move, npcX: 0.6, npcLook: -0.5),
      );
      expect(writes, <String>['npc2=move', 'npc2X=0.6', 'npc2Look=-0.5']);
      writes.clear();
      // only the first NPC moves: npc2* is not rewritten
      writer.write(
        const NpcIntent(npc: NpcState.idle),
        second: const NpcIntent(npc: NpcState.move, npcX: 0.6, npcLook: -0.5),
      );
      expect(writes, <String>['npc=idle']);
    });

    test('without a second intent npc2* is never written', () {
      final SceneNpcWriter writer = SceneNpcWriter(
        setEnum: setEnum,
        setNumber: setNumber,
      );
      writer.write(NpcIntent.rest);
      expect(writes.where((String w) => w.startsWith('npc2')), isEmpty);
    });

    test('the follower follows both sources and writes both to a new file', () {
      final ValueNotifier<NpcIntent> first = ValueNotifier<NpcIntent>(
        NpcIntent.rest,
      );
      final ValueNotifier<NpcIntent> gulls = ValueNotifier<NpcIntent>(
        NpcIntent.away,
      );
      addTearDown(first.dispose);
      addTearDown(gulls.dispose);
      final SceneNpcFollower follower = SceneNpcFollower();
      addTearDown(follower.dispose);
      follower.follow(first, second: gulls);
      follower.load(setEnum, setNumber);
      expect(writes, <String>[
        'npc=rest',
        'npcX=0.0',
        'npcLook=0.0',
        'npc2=away',
        'npc2X=1.0',
        'npc2Look=0.0',
      ]);
      writes.clear();
      gulls.value = const NpcIntent(npc: NpcState.idle);
      expect(writes, <String>['npc2=idle', 'npc2X=0.0']);
      writes.clear();
      follower.unload();
      follower.load(setEnum, setNumber);
      expect(writes, hasLength(6), reason: 'a fresh file gets everything');
    });

    test('a second override wins over the second source', () {
      final ValueNotifier<NpcIntent> gulls = ValueNotifier<NpcIntent>(
        NpcIntent.away,
      );
      addTearDown(gulls.dispose);
      final SceneNpcFollower follower = SceneNpcFollower();
      addTearDown(follower.dispose);
      follower.follow(null, second: gulls);
      follower.load(setEnum, setNumber);
      writes.clear();
      follower.follow(
        null,
        second: gulls,
        secondOverride: const NpcIntent(npc: NpcState.react),
      );
      expect(writes, <String>['npc2=react', 'npc2X=0.0']);
      writes.clear();
      gulls.value = const NpcIntent(npc: NpcState.idle);
      expect(writes, isEmpty, reason: 'the override holds');
    });

    test('a follower with no second source leaves npc2* alone', () {
      final SceneNpcFollower follower = SceneNpcFollower();
      addTearDown(follower.dispose);
      follower.load(setEnum, setNumber);
      expect(writes.where((String w) => w.startsWith('npc2')), isEmpty);
    });
  });
}
