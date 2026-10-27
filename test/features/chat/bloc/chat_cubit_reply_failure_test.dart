import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/models/talking_phase.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_state.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

import 'chat_reply_failure_harness.dart';

void main() {
  setUpAll(ReplyRig.registerFallbacks);

  /// Runs one scripted reply; returns the streaming states the lifecycle
  /// service broadcast and the talking phase while the reply was pending.
  Future<({List<ChatStatus> events, TalkingPhase pending})> reply(
    ReplyRig rig,
  ) async {
    final List<ChatStatus> events = <ChatStatus>[];
    final StreamSubscription<ChatStatus> sub = rig
        .lifecycle
        .streamingStateChangedEvents
        .listen(events.add);
    final Future<void> done = rig.chat.streamResponse(
      'Hello?',
      onlyText: true,
      avatar: const Avatar(),
      currentChat: const Chat(id: 'c1'),
      language: 'en',
    );
    await rig.streaming.started.future;
    await pumpEventQueue();
    final TalkingPhase pending = rig.talking.state.phase;
    rig.streaming.release.complete();
    await done;
    await pumpEventQueue();
    await sub.cancel();
    return (events: events, pending: pending);
  }

  for (final ReplyEnd end in <ReplyEnd>[ReplyEnd.error, ReplyEnd.thrown]) {
    test('a failed reply (${end.name}) ends the thinking state', () async {
      final ReplyRig rig = ReplyRig(end);
      addTearDown(rig.close);

      final ({List<ChatStatus> events, TalkingPhase pending}) result =
          await reply(rig);

      expect(result.pending, TalkingPhase.generating);
      expect(result.events, <ChatStatus>[ChatStatus.typing, ChatStatus.error]);
      expect(rig.chat.state.status, ChatStatus.error);
      expect(rig.chat.state.error, isA<UnknownFailure>());
      expect(rig.chat.state.activeTool, isNull);
      expect(rig.talking.state.phase, TalkingPhase.idle);
    });
  }

  test('an interrupted reply ends idle too', () async {
    final ReplyRig rig = ReplyRig(ReplyEnd.interrupted);
    addTearDown(rig.close);

    final ({List<ChatStatus> events, TalkingPhase pending}) result =
        await reply(rig);

    expect(result.pending, TalkingPhase.generating);
    expect(rig.talking.state.phase, TalkingPhase.idle);
  });

  test(
    'a successful reply keeps "generating" for the TTS to take over',
    () async {
      final ReplyRig rig = ReplyRig(ReplyEnd.success);
      addTearDown(rig.close);

      final ({List<ChatStatus> events, TalkingPhase pending}) result =
          await reply(rig);

      expect(result.events, <ChatStatus>[
        ChatStatus.typing,
        ChatStatus.success,
      ]);
      expect(rig.chat.state.status, ChatStatus.success);
    },
  );
}
