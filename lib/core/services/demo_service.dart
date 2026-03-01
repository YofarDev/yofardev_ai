import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/avatar/bloc/avatar_cubit.dart';
import '../../features/chat/bloc/chats_cubit.dart';
import '../models/avatar_config.dart';
import '../models/demo_script.dart';
import '../../features/demo/services/demo_controller.dart';
import 'llm/fake_llm_service.dart';

class DemoService {
  static final DemoService _instance = DemoService._internal();
  factory DemoService() => _instance;
  DemoService._internal();

  final DemoController _demoController = DemoController();
  final FakeLlmService _fakeLlmService = FakeLlmService();

  DemoController get controller => _demoController;
  FakeLlmService get fakeLlmService => _fakeLlmService;

  /// Activate demo mode with a script
  Future<void> activateDemo({
    required BuildContext context,
    required DemoScript script,
  }) async {
    // Set initial background
    final AvatarCubit avatarCubit = context.read<AvatarCubit>();
    final Avatar currentAvatar = avatarCubit.state.avatar;

    final AvatarBackgrounds initialBg = AvatarBackgrounds.values.firstWhere(
      (AvatarBackgrounds bg) => bg.name == script.initialBackground,
      orElse: () => AvatarBackgrounds.office,
    );

    if (currentAvatar.background != initialBg) {
      avatarCubit.onNewAvatarConfig(
        context.read<ChatsCubit>().state.currentChat.id,
        AvatarConfig(background: initialBg),
      );
    }

    // Convert demo responses to fake LLM responses
    final List<FakeLlmResponse> responses = script.responses;

    // Start countdown
    await _demoController.startCountdown();

    // Activate fake LLM with the responses
    _fakeLlmService.activate(responses);

    _demoController.complete();
  }

  /// Deactivate demo mode
  void deactivateDemo() {
    _fakeLlmService.deactivate();
    _demoController.reset();
  }

  bool get isActive => _fakeLlmService.isActive;
}
