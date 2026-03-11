import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/services/avatar_animation_service.dart';
import 'package:yofardev_ai/features/avatar/domain/models/avatar_animation.dart';
import 'package:yofardev_ai/features/avatar/domain/repositories/avatar_repository.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/features/avatar/widgets/animated_background_avatar.dart';
import 'package:yofardev_ai/features/chat/domain/models/chat.dart';

class MockAvatarAnimationService implements AvatarAnimationService {
  @override
  Stream<AvatarAnimation> get animations =>
      const Stream<AvatarAnimation>.empty();

  @override
  void dispose() {}

  @override
  Future<void> playNewChatSequence(String chatId, AvatarConfig config) async {}
}

void main() {
  group('AnimatedBackgroundAvatar', () {
    late AvatarCubit avatarCubit;
    late MockAvatarAnimationService mockAnimationService;

    setUp(() {
      mockAnimationService = MockAvatarAnimationService();
      avatarCubit = AvatarCubit(MockAvatarRepository(), mockAnimationService);
      avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
    });

    tearDown(() {
      avatarCubit.close();
    });

    Widget makeTestableWidget() {
      return BlocProvider<AvatarCubit>.value(
        value: avatarCubit,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 800,
              child: Stack(children: <Widget>[AnimatedBackgroundAvatar()]),
            ),
          ),
        ),
      );
    }

    testWidgets('renders Image.asset with background path', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(makeTestableWidget());

      // Assert
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('uses AnimatedSwitcher for transitions', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(makeTestableWidget());

      // Assert
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
    });

    testWidgets('rebuilds when background changes', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(makeTestableWidget());
      final Image initialImage = tester.widget<Image>(find.byType(Image));

      // Act
      avatarCubit.loadAvatar('test-chat');
      await tester.pumpAndSettle();

      // Assert - new image with different key
      final Image newImage = tester.widget<Image>(find.byType(Image));
      expect(
        (initialImage.image as AssetImage).assetName,
        isNot((newImage.image as AssetImage).assetName),
      );
    });
  });
}

// Mock repository for testing
class MockAvatarRepository implements AvatarRepository {
  @override
  Future<Either<Exception, Chat>> getChat(String chatId) async {
    final Chat chat = Chat(
      id: chatId,
      title: 'Test Chat',
      persona: ChatPersona.assistant,
      avatar: const Avatar(background: AvatarBackgrounds.beach),
    );
    final Either<Exception, Chat> result = Right<Exception, Chat>(chat);
    return result;
  }

  @override
  Future<Either<Exception, void>> updateAvatar(
    String chatId,
    Avatar avatar,
  ) async {
    final Either<Exception, void> result = Right<Exception, void>(null);
    return result;
  }
}
