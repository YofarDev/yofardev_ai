import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/core/repositories/chat_repository.dart';
import 'package:yofardev_ai/features/demo/data/repositories/demo_repository_impl.dart';

class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late MockChatRepository chatRepository;
  late DemoRepositoryImpl repo;
  late Chat chat;

  setUp(() {
    chatRepository = MockChatRepository();
    repo = DemoRepositoryImpl(chatRepository: chatRepository);
    chat = Chat(id: 'c1');
    registerFallbackValue(chat.avatar);
  });

  test('setAvatarBackground persists a copy of the avatar with the scene',
      () async {
    when(() => chatRepository.getChat('c1'))
        .thenAnswer((_) async => Result<Chat?>.ok(chat));
    when(() => chatRepository.updateAvatar('c1', any()))
        .thenAnswer((_) async => Result<void>.ok(null));

    final Result<void> result =
        await repo.setAvatarBackground('c1', AvatarScene.beach);

    expect(result.isOk, isTrue);
    final dynamic saved = verify(
      () => chatRepository.updateAvatar('c1', captureAny()),
    ).captured.single;
    expect((saved as Avatar).background, AvatarScene.beach);
  });

  test('setAvatarBackground on an unknown chat is a StorageFailure',
      () async {
    when(() => chatRepository.getChat('nope'))
        .thenAnswer((_) async => Result<Chat?>.ok(null));

    final Result<void> result =
        await repo.setAvatarBackground('nope', AvatarScene.beach);

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<StorageFailure>(),
    );
    verifyNever(() => chatRepository.updateAvatar(any(), any()));
  });

  test('setAvatarBackground passes a repository error through as storage',
      () async {
    when(() => chatRepository.getChat('c1'))
        .thenAnswer((_) async => Result<Chat?>.err(
              const StorageFailure('nope'),
            ));

    final Result<void> result =
        await repo.setAvatarBackground('c1', AvatarScene.beach);

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<StorageFailure>(),
    );
  });

  test('getCurrentChatId returns the current chat id', () async {
    when(() => chatRepository.getCurrentChat())
        .thenAnswer((_) async => Result<Chat>.ok(chat));

    final Result<String> result = await repo.getCurrentChatId();

    expect(
      result.when(err: (_) => throw StateError('err'), ok: (String id) => id),
      'c1',
    );
  });

  test('getCurrentChatId without a current chat is a StorageFailure',
      () async {
    when(() => chatRepository.getCurrentChat()).thenAnswer(
      (_) async => Result<Chat>.err(const StorageFailure('none')),
    );

    final Result<String> result = await repo.getCurrentChatId();

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<StorageFailure>(),
    );
  });

  test('a throwing repository maps to a typed failure', () async {
    when(() => chatRepository.getCurrentChat())
        .thenThrow(TimeoutException('timeout'));

    final Result<String> result = await repo.getCurrentChatId();

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<NetworkFailure>(),
    );
  });
}
