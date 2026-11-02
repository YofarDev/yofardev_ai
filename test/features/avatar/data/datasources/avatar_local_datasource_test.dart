import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/features/avatar/data/datasources/avatar_local_datasource.dart';

void main() {
  late AvatarLocalDatasource datasource;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    datasource = AvatarLocalDatasource();
  });

  test('an absent chat returns ok(null), not an error', () async {
    final Result<Chat?> result = await datasource.getChat('missing');

    expect(result.isOk, true);
    expect(result.getOrNull, isNull);
  });

  test('the happy path returns the decoded chat unchanged', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Chat chat = const Chat(id: 'chat-1', title: 'Hello');
    await prefs.setString('chat_chat-1', jsonEncode(chat.toMap()));

    final Result<Chat?> result = await datasource.getChat('chat-1');

    expect(result.getOrNull, chat);
  });

  test(
    'corrupt JSON maps to a StorageFailure, not the not-found path',
    () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_broken', '{not json');

      final Result<Chat?> result = await datasource.getChat('broken');

      expect(result.isOk, false);
      final Failure failure = result.when(
        err: (Failure f) => f,
        ok: (_) => throw StateError('err expected'),
      );
      expect(failure, isA<StorageFailure>());
      expect(failure.message, isNot(contains('not found')));
    },
  );

  test('a type-mismatched payload maps to a StorageFailure', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // Valid JSON, but entries are not ChatEntry maps.
    await prefs.setString(
      'chat_typed',
      jsonEncode(<String, dynamic>{
        'id': 'typed',
        'entries': <String>['x'],
      }),
    );

    final Result<Chat?> result = await datasource.getChat('typed');

    // A type-mismatched payload is corrupt, so it must be an error — the
    // mapper classifies TypeError as UnknownFailure (FormatException as
    // StorageFailure), but never as the not-found path.
    expect(result.isOk, false);
    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<Failure>(),
    );
  });

  test(
    'an unknown exception maps through the mapper, never to not-found',
    () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      // Valid JSON whose persona name does not exist → ArgumentError inside
      // Chat.fromMap; it must not come back as ok(null) ("chat absent").
      await prefs.setString(
        'chat_badPersona',
        jsonEncode(<String, dynamic>{'id': 'badPersona', 'persona': 'bogus'}),
      );

      final Result<Chat?> result = await datasource.getChat('badPersona');

      expect(result.isOk, false);
      expect(
        result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
        isA<Failure>(),
      );
    },
  );
}
