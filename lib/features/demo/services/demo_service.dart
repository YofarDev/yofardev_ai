import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:yofardev_ai/features/avatar/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/features/demo/models/demo_script.dart';
import 'package:yofardev_ai/features/demo/services/demo_controller.dart';
import 'package:yofardev_ai/core/services/llm/fake_llm_service.dart';
import 'package:yofardev_ai/logic/chat/chats_cubit.dart';
import 'package:yofardev_ai/models/avatar.dart';

/// Service for managing demo mode
///
/// Coordinates the demo controller, fake LLM service, and avatar
/// to provide a scripted demo experience
class DemoService {
  static final DemoService _instance = DemoService._internal();
  factory DemoService() => _instance;
  DemoService._internal();

  final DemoController _demoController = DemoController();
  final FakeLlmService _fakeLlmService = FakeLlmService();

  DemoController get controller => _demoController;
  FakeLlmService get fakeLlmService => _fakeLlmService;

  /// Whether demo mode is currently active
  bool get isActive => _fakeLlmService.isActive;

  /// Get the number of remaining demo responses
  int get remainingResponses => _fakeLlmService.remainingResponses;

  /// Activate demo mode with a script
  ///
  /// Sets the initial avatar background, starts countdown,
  /// and activates the fake LLM service with scripted responses
  Future<void> activateDemo({
    required BuildContext context,
    required DemoScript script,
  }) async {
    debugPrint('Activating demo: ${script.name}');

    // Set initial background
    final AvatarCubit avatarCubit = context.read<AvatarCubit>();
    final Avatar currentAvatar = avatarCubit.state.avatar;

    final AvatarBackgrounds initialBg = AvatarBackgrounds.values.firstWhere(
      (AvatarBackgrounds bg) => bg.name == script.initialBackground,
      orElse: () => AvatarBackgrounds.office,
    );

    if (currentAvatar.background != initialBg) {
      final String chatId = context.read<ChatsCubit>().state.currentChat.id;
      avatarCubit.onNewAvatarConfig(
        chatId,
        AvatarConfig(background: initialBg),
      );
      debugPrint('Set initial background to: ${initialBg.name}');
    }

    // Start countdown
    await _demoController.startCountdown();

    // Activate fake LLM with the responses
    _fakeLlmService.activate(script.responses);
    _demoController.activate();

    debugPrint('Demo activated with ${script.responses.length} responses');
  }

  /// Deactivate demo mode
  ///
  /// Resets the fake LLM service and demo controller
  void deactivateDemo() {
    debugPrint('Deactivating demo mode');
    _fakeLlmService.deactivate();
    _demoController.reset();
  }

  /// Reset the current demo to the beginning
  void resetDemo() {
    debugPrint('Resetting demo to beginning');
    _fakeLlmService.reset();
    _demoController.reset();
  }
}
