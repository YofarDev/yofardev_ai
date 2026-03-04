import 'package:fpdart/fpdart.dart';

import '../../../chat/domain/models/chat.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_datasource.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDatasource _datasource = SettingsLocalDatasource();

  @override
  Future<Either<Exception, String?>> getLanguage() async {
    try {
      final String? language = await _datasource.getLanguage();
      return Right<Exception, String?>(language);
    } catch (e) {
      return Left<Exception, String?>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> setLanguage(String language) async {
    try {
      await _datasource.setLanguage(language);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, bool>> getSoundEffects() async {
    try {
      final bool enabled = await _datasource.getSoundEffects();
      return Right<Exception, bool>(enabled);
    } catch (e) {
      return Left<Exception, bool>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> setSoundEffects(bool enabled) async {
    try {
      await _datasource.setSoundEffects(enabled);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, String?>> getUsername() async {
    try {
      final String? username = await _datasource.getUsername();
      return Right<Exception, String?>(username);
    } catch (e) {
      return Left<Exception, String?>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> setUsername(String username) async {
    try {
      await _datasource.setUsername(username);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, String>> getSystemPrompt() async {
    try {
      final String prompt = await _datasource.getBaseSystemPrompt();
      return Right<Exception, String>(prompt);
    } catch (e) {
      return Left<Exception, String>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> setSystemPrompt(String prompt) async {
    try {
      await _datasource.setBaseSystemPrompt(prompt);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, ChatPersona>> getPersona() async {
    try {
      final ChatPersona persona = await _datasource.getPersona();
      return Right<Exception, ChatPersona>(persona);
    } catch (e) {
      return Left<Exception, ChatPersona>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> setPersona(ChatPersona persona) async {
    try {
      await _datasource.setPersona(persona);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }
}
