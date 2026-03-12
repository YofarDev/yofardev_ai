import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../../../core/utils/logger.dart';
import '../../../../core/services/llm/fake_llm_service.dart';
import '../../../../core/models/avatar_config.dart';
import '../../domain/models/demo_script.dart';
import '../../domain/repositories/demo_repository.dart';
import '../../../../core/services/demo_controller.dart';

/// Service for managing demo mode
///
/// Coordinates the demo controller, fake LLM service, and repository
/// to provide a scripted demo experience without direct UI dependencies
class DemoService {
  final DemoRepository _repository;
  final DemoController _demoController;
  final FakeLlmService _fakeLlmService;

  DemoService({
    required DemoRepository repository,
    required DemoController demoController,
    required FakeLlmService fakeLlmService,
  }) : _repository = repository,
       _demoController = demoController,
       _fakeLlmService = fakeLlmService;

  DemoController get controller => _demoController;

  /// Whether demo mode is currently active
  bool get isActive => _fakeLlmService.isActive;

  /// Get the number of remaining demo responses
  int get remainingResponses => _fakeLlmService.remainingResponses;

  /// Activate demo mode with a script
  ///
  /// Sets the initial avatar background, starts countdown,
  /// and activates the fake LLM service with scripted responses
  Future<void> activateDemo({
    required String chatId,
    required DemoScript script,
  }) async {
    AppLogger.info('Activating demo: ${script.name}', tag: 'DemoService');

    // Set initial background using repository
    final AvatarBackgrounds initialBg = AvatarBackgrounds.values.firstWhere(
      (AvatarBackgrounds bg) => bg.name == script.initialBackground,
      orElse: () => AvatarBackgrounds.office,
    );

    final Either<Exception, void> result = await _repository
        .setAvatarBackground(chatId, initialBg);
    if (result.isRight()) {
      AppLogger.debug(
        'Set initial background to: ${initialBg.name}',
        tag: 'DemoService',
      );
    }

    // Start countdown
    await _demoController.startCountdown();

    // Activate fake LLM with the responses
    _fakeLlmService.activate(script.responses);
    _demoController.activate();

    AppLogger.info(
      'Demo activated with ${script.responses.length} responses',
      tag: 'DemoService',
    );
  }

  /// Deactivate demo mode
  ///
  /// Resets the fake LLM service and demo controller
  void deactivateDemo() {
    AppLogger.info('Deactivating demo mode', tag: 'DemoService');
    _fakeLlmService.deactivate();
    _demoController.reset();
  }

  /// Reset the current demo to the beginning
  void resetDemo() {
    AppLogger.info('Resetting demo to beginning', tag: 'DemoService');
    _fakeLlmService.reset();
    _demoController.reset();
  }
}
