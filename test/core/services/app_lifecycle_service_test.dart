import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:yofardev_ai/core/models/app_lifecycle_event.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';
import 'package:yofardev_ai/core/models/demo_script.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_state.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_state.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_state.dart';

void main() {
  late AppLifecycleService service;

  setUp(() {
    service = AppLifecycleService();
  });

  tearDown(() {
    service.dispose();
  });

  group('AppLifecycleService', () {
    group('emitNewChatEntry', () {
      test('skips non-yofardev entries', () async {
        final ChatEntry userEntry = ChatEntry(
          id: '1',
          entryType: EntryType.user,
          body: 'Hello',
          timestamp: DateTime.now(),
        );

        final List<NewChatEntryPayload> events = <NewChatEntryPayload>[];
        final StreamSubscription<NewChatEntryPayload> subscription = service
            .newChatEntryEvents
            .listen(events.add);

        service.emitNewChatEntry(userEntry, 'chat1', const AvatarConfig());

        await Future<dynamic>.delayed(const Duration(milliseconds: 10));

        expect(events, isEmpty);
        await subscription.cancel();
      });

      test('skips empty yofardev entries', () async {
        final ChatEntry emptyEntry = ChatEntry(
          id: '1',
          entryType: EntryType.yofardev,
          body: '',
          timestamp: DateTime.now(),
        );

        final List<NewChatEntryPayload> events = <NewChatEntryPayload>[];
        final StreamSubscription<NewChatEntryPayload> subscription = service
            .newChatEntryEvents
            .listen(events.add);

        service.emitNewChatEntry(emptyEntry, 'chat1', const AvatarConfig());

        await Future<dynamic>.delayed(const Duration(milliseconds: 10));

        expect(events, isEmpty);
        await subscription.cancel();
      });

      test('emits event when background changes', () async {
        final ChatEntry entry = ChatEntry(
          id: '1',
          entryType: EntryType.yofardev,
          body: '{"background": "beach"}',
          timestamp: DateTime.now(),
        );

        final List<NewChatEntryPayload> events = <NewChatEntryPayload>[];
        final StreamSubscription<NewChatEntryPayload> subscription = service
            .newChatEntryEvents
            .listen(events.add);

        service.emitNewChatEntry(
          entry,
          'chat1',
          const AvatarConfig(background: AvatarBackgrounds.forest),
        );

        await Future<dynamic>.delayed(const Duration(milliseconds: 10));

        expect(events, hasLength(1));
        expect(
          events.first.newAvatarConfig.background,
          AvatarBackgrounds.beach,
        );
        expect(
          events.first.newAvatarConfig.specials,
          AvatarSpecials.leaveAndComeBack,
        );
        await subscription.cancel();
      });

      test('emits event when clothes change', () async {
        final ChatEntry entry = ChatEntry(
          id: '1',
          entryType: EntryType.yofardev,
          body: '{"top": "tshirt"}',
          timestamp: DateTime.now(),
        );

        final List<NewChatEntryPayload> events = <NewChatEntryPayload>[];
        final StreamSubscription<NewChatEntryPayload> subscription = service
            .newChatEntryEvents
            .listen(events.add);

        service.emitNewChatEntry(
          entry,
          'chat1',
          const AvatarConfig(top: AvatarTop.pinkHoodie),
        );

        await Future<dynamic>.delayed(const Duration(milliseconds: 10));

        expect(events, hasLength(1));
        expect(events.first.newAvatarConfig.top, AvatarTop.tshirt);
        expect(
          events.first.newAvatarConfig.specials,
          AvatarSpecials.outOfScreen,
        );
        await subscription.cancel();
      });

      test('does not emit event when nothing changes', () async {
        final ChatEntry entry = ChatEntry(
          id: '1',
          entryType: EntryType.yofardev,
          body: '{}',
          timestamp: DateTime.now(),
        );

        final List<NewChatEntryPayload> events = <NewChatEntryPayload>[];
        final StreamSubscription<NewChatEntryPayload> subscription = service
            .newChatEntryEvents
            .listen(events.add);

        service.emitNewChatEntry(entry, 'chat1', const AvatarConfig());

        await Future<dynamic>.delayed(const Duration(milliseconds: 10));

        expect(events, isEmpty);
        await subscription.cancel();
      });
    });

    group('emitStreamingStateChanged', () {
      test('emits status events', () async {
        final List<ChatStatus> events = <ChatStatus>[];
        final StreamSubscription<ChatStatus> subscription = service
            .streamingStateChangedEvents
            .listen(events.add);

        service.emitStreamingStateChanged(ChatStatus.streaming);
        await Future<dynamic>.delayed(const Duration(milliseconds: 10));
        expect(events, equals(<ChatStatus>[ChatStatus.streaming]));

        service.emitStreamingStateChanged(ChatStatus.error);
        await Future<dynamic>.delayed(const Duration(milliseconds: 10));
        expect(
          events,
          equals(<ChatStatus>[ChatStatus.streaming, ChatStatus.error]),
        );

        await subscription.cancel();
      });
    });

    group('emitAvatarAnimationChanged', () {
      test('emits animation events', () async {
        final List<AvatarStatusAnimation> events = <AvatarStatusAnimation>[];
        final StreamSubscription<AvatarStatusAnimation> subscription = service
            .avatarAnimationChangedEvents
            .listen(events.add);

        service.emitAvatarAnimationChanged(AvatarStatusAnimation.leaving);
        await Future<dynamic>.delayed(const Duration(milliseconds: 10));
        expect(
          events,
          equals(<AvatarStatusAnimation>[AvatarStatusAnimation.leaving]),
        );

        service.emitAvatarAnimationChanged(AvatarStatusAnimation.coming);
        await Future<dynamic>.delayed(const Duration(milliseconds: 10));
        expect(
          events,
          equals(<AvatarStatusAnimation>[
            AvatarStatusAnimation.leaving,
            AvatarStatusAnimation.coming,
          ]),
        );

        await subscription.cancel();
      });
    });

    group('emitTalkingStateChanged', () {
      test('emits talking state events', () async {
        final List<TalkingState> events = <TalkingState>[];
        final StreamSubscription<TalkingState> subscription = service
            .talkingStateChangedEvents
            .listen(events.add);

        final TalkingState state1 = const TalkingState.idle();
        final TalkingState state2 = const TalkingState.speaking();

        service.emitTalkingStateChanged(state1);
        await Future<dynamic>.delayed(const Duration(milliseconds: 10));
        expect(events, equals(<TalkingState>[state1]));

        service.emitTalkingStateChanged(state2);
        await Future<dynamic>.delayed(const Duration(milliseconds: 10));
        expect(events, equals(<TalkingState>[state1, state2]));

        await subscription.cancel();
      });
    });

    group('emitChatChanged', () {
      test('emits chat ID events', () async {
        final List<String> events = <String>[];
        final StreamSubscription<String> subscription = service
            .chatChangedEvents
            .listen(events.add);

        service.emitChatChanged('chat1');
        await Future<dynamic>.delayed(const Duration(milliseconds: 10));
        expect(events, equals(<String>['chat1']));

        service.emitChatChanged('chat2');
        await Future<dynamic>.delayed(const Duration(milliseconds: 10));
        expect(events, equals(<String>['chat1', 'chat2']));

        await subscription.cancel();
      });
    });

    group('emitDemoScriptChanged', () {
      test('emits demo script events', () async {
        final List<DemoScript> events = <DemoScript>[];
        final StreamSubscription<DemoScript> subscription = service
            .demoScriptChangedEvents
            .listen(events.add);

        final DemoScript script = const DemoScript(
          name: 'Test Demo',
          description: 'Test',
          responses: <FakeLlmResponse>[],
        );

        service.emitDemoScriptChanged(script);
        await Future<dynamic>.delayed(const Duration(milliseconds: 10));
        expect(events, equals(<DemoScript>[script]));

        await subscription.cancel();
      });
    });
  });
}
