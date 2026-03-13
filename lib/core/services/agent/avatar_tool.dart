import '../../models/avatar_config.dart';
import '../../models/function_info.dart';
import 'agent_tool.dart';
import '../../../features/chat/presentation/bloc/chat_cubit.dart';
import '../../di/service_locator.dart';
import '../avatar_animation_service.dart';
import '../../utils/logger.dart';

/// Agent tool that allows the LLM to change the avatar's appearance
/// including background, clothes (hat, top), glasses, and accessories.
class AvatarTool extends AgentTool {
  ChatCubit get _chatCubit => getIt<ChatCubit>();
  AvatarAnimationService get _avatarAnimationService =>
      getIt<AvatarAnimationService>();

  @override
  String get name => 'change_avatar';

  @override
  String get description =>
      'Changes the avatar appearance. '
      'Can change background, hat, top (shirt), glasses, or costume. '
      'All parameters are optional - only include the ones you want to change.';

  @override
  List<Parameter> get parameters => <Parameter>[
    Parameter(
      name: 'background',
      description:
          'Background scene. '
          'Options: lake, beach, mountain, space, city, forest, desert, sunset, snow, underwater',
      type: 'string',
      isRequired: false,
    ),
    Parameter(
      name: 'hat',
      description:
          'Hat/headwear. '
          'Options: none, french_beret, beanie, cap, top_hat, wizard_hat, crown, santa_hat',
      type: 'string',
      isRequired: false,
    ),
    Parameter(
      name: 'top',
      description:
          'Top/shirt. '
          'Options: pink_hoodie, long_coat, t_shirt, suit, dress, superhero, space_suit',
      type: 'string',
      isRequired: false,
    ),
    Parameter(
      name: 'glasses',
      description:
          'Eyewear. '
          'Options: none, glasses, sunglasses, monocle, safety_goggles',
      type: 'string',
      isRequired: false,
    ),
    Parameter(
      name: 'costume',
      description:
          'Special costume. '
          'Options: none, astronaut, doctor, police, chef, pirate, ninja',
      type: 'string',
      isRequired: false,
    ),
    Parameter(
      name: 'specials',
      description:
          'Special effects. '
          'Options: none, sparkles, smoke, fire, ice, hearts, stars',
      type: 'string',
      isRequired: false,
    ),
  ];

  @override
  Map<String, String> get requiredConfigKeys => <String, String>{};

  @override
  Future<String> execute(
    Map<String, dynamic> args,
    Map<String, dynamic> configValues,
  ) async {
    try {
      // Build AvatarConfig from provided arguments
      final AvatarConfigBuilder configBuilder = AvatarConfigBuilder();

      // Parse background if provided
      final String? backgroundStr = args['background'] as String?;
      if (backgroundStr != null) {
        final AvatarBackgrounds? background = _parseBackground(backgroundStr);
        if (background == null) {
          return 'Error: Invalid background "$backgroundStr". '
              'Valid options: lake, beach, mountain, space, city, forest, desert, sunset, snow, underwater';
        }
        configBuilder.background = background;
      }

      // Parse hat if provided
      final String? hatStr = args['hat'] as String?;
      if (hatStr != null) {
        final AvatarHat? hat = _parseHat(hatStr);
        if (hat == null) {
          return 'Error: Invalid hat "$hatStr". '
              'Valid options: none, french_beret, beanie, cap, top_hat, wizard_hat, crown, santa_hat';
        }
        configBuilder.hat = hat;
      }

      // Parse top if provided
      final String? topStr = args['top'] as String?;
      if (topStr != null) {
        final AvatarTop? top = _parseTop(topStr);
        if (top == null) {
          return 'Error: Invalid top "$topStr". '
              'Valid options: pink_hoodie, long_coat, t_shirt, suit, dress, superhero, space_suit';
        }
        configBuilder.top = top;
      }

      // Parse glasses if provided
      final String? glassesStr = args['glasses'] as String?;
      if (glassesStr != null) {
        final AvatarGlasses? glasses = _parseGlasses(glassesStr);
        if (glasses == null) {
          return 'Error: Invalid glasses "$glassesStr". '
              'Valid options: none, glasses, sunglasses, monocle, safety_goggles';
        }
        configBuilder.glasses = glasses;
      }

      // Parse costume if provided
      final String? costumeStr = args['costume'] as String?;
      if (costumeStr != null) {
        final AvatarCostume? costume = _parseCostume(costumeStr);
        if (costume == null) {
          return 'Error: Invalid costume "$costumeStr". '
              'Valid options: none, astronaut, doctor, police, chef, pirate, ninja';
        }
        configBuilder.costume = costume;
      }

      // Parse specials if provided
      final String? specialsStr = args['specials'] as String?;
      if (specialsStr != null) {
        final AvatarSpecials? specials = _parseSpecials(specialsStr);
        if (specials == null) {
          return 'Error: Invalid special effect "$specialsStr". '
              'Valid options: none, sparkles, smoke, fire, ice, hearts, stars';
        }
        configBuilder.specials = specials;
      }

      // Check if any changes were requested
      if (backgroundStr == null &&
          hatStr == null &&
          topStr == null &&
          glassesStr == null &&
          costumeStr == null &&
          specialsStr == null) {
        return 'Error: No avatar changes requested. '
            'Please specify at least one parameter to change (background, hat, top, glasses, costume, or specials).';
      }

      // Build the config
      final AvatarConfig newConfig = configBuilder.build();

      AppLogger.debug(
        'AvatarTool: newConfig=$newConfig, background=${newConfig.background}, top=${newConfig.top}, hat=${newConfig.hat}',
        tag: 'AvatarTool',
      );

      // Determine which animation to use based on what changed
      // Background changes use leaveAndComeBack animation
      // Clothes changes use outOfScreen animation (go down and up)
      final bool backgroundChanged = backgroundStr != null;
      final bool clothesChanged =
          hatStr != null ||
          topStr != null ||
          glassesStr != null ||
          costumeStr != null;

      final AvatarConfig configWithAnimation = backgroundChanged
          ? newConfig.copyWith(specials: AvatarSpecials.leaveAndComeBack)
          : clothesChanged
          ? newConfig.copyWith(specials: AvatarSpecials.outOfScreen)
          : newConfig;

      AppLogger.debug(
        'AvatarTool: configWithAnimation=$configWithAnimation, specials=${configWithAnimation.specials}',
        tag: 'AvatarTool',
      );

      // Determine which method to call
      // If only background changed, use updateBackgroundOpenedChat
      // Otherwise use updateAvatarOpenedChat for multiple changes
      if (backgroundStr != null &&
          hatStr == null &&
          topStr == null &&
          glassesStr == null &&
          costumeStr == null &&
          specialsStr == null) {
        AppLogger.debug(
          'AvatarTool: calling updateBackgroundOpenedChat',
          tag: 'AvatarTool',
        );
        await _chatCubit.updateBackgroundOpenedChat(newConfig.background!);
      } else {
        AppLogger.debug(
          'AvatarTool: calling updateAvatarOpenedChat',
          tag: 'AvatarTool',
        );
        await _chatCubit.updateAvatarOpenedChat(newConfig);
      }

      // Notify AvatarCubit via animation service to update UI
      // This triggers the animation and updates the avatar display
      final String chatId = _chatCubit.openedChat.id;
      AppLogger.debug(
        'AvatarTool: emitting updateConfig for chatId=$chatId',
        tag: 'AvatarTool',
      );
      _avatarAnimationService.emitUpdateConfig(chatId, configWithAnimation);
      AppLogger.debug(
        'AvatarTool: emitUpdateConfig called successfully',
        tag: 'AvatarTool',
      );

      // Generate success message
      final List<String> changes = <String>[];
      if (backgroundStr != null) changes.add('background to $backgroundStr');
      if (hatStr != null) changes.add('hat to $hatStr');
      if (topStr != null) changes.add('top to $topStr');
      if (glassesStr != null) changes.add('glasses to $glassesStr');
      if (costumeStr != null) changes.add('costume to $costumeStr');
      if (specialsStr != null) changes.add('special effects to $specialsStr');

      return 'Successfully changed ${changes.join(', ')}.';
    } catch (e) {
      return 'Error changing avatar: $e';
    }
  }

  AvatarBackgrounds? _parseBackground(String value) {
    final String normalized = value.toLowerCase().replaceAll(' ', '_');
    return AvatarBackgrounds.values.cast<AvatarBackgrounds?>().firstWhere(
      (AvatarBackgrounds? e) => e?.name.toLowerCase() == normalized,
      orElse: () => null,
    );
  }

  AvatarHat? _parseHat(String value) {
    final String normalized = value.toLowerCase().replaceAll(' ', '_');
    return AvatarHat.values.cast<AvatarHat?>().firstWhere(
      (AvatarHat? e) => e?.name.toLowerCase() == normalized,
      orElse: () => null,
    );
  }

  AvatarTop? _parseTop(String value) {
    final String normalized = value.toLowerCase().replaceAll(' ', '_');
    return AvatarTop.values.cast<AvatarTop?>().firstWhere(
      (AvatarTop? e) => e?.name.toLowerCase() == normalized,
      orElse: () => null,
    );
  }

  AvatarGlasses? _parseGlasses(String value) {
    final String normalized = value.toLowerCase().replaceAll(' ', '_');
    return AvatarGlasses.values.cast<AvatarGlasses?>().firstWhere(
      (AvatarGlasses? e) => e?.name.toLowerCase() == normalized,
      orElse: () => null,
    );
  }

  AvatarCostume? _parseCostume(String value) {
    final String normalized = value.toLowerCase().replaceAll(' ', '_');
    return AvatarCostume.values.cast<AvatarCostume?>().firstWhere(
      (AvatarCostume? e) => e?.name.toLowerCase() == normalized,
      orElse: () => null,
    );
  }

  AvatarSpecials? _parseSpecials(String value) {
    final String normalized = value.toLowerCase().replaceAll(' ', '_');
    return AvatarSpecials.values.cast<AvatarSpecials?>().firstWhere(
      (AvatarSpecials? e) => e?.name.toLowerCase() == normalized,
      orElse: () => null,
    );
  }
}

/// Helper class to build AvatarConfig with optional fields
class AvatarConfigBuilder {
  AvatarBackgrounds? background;
  AvatarHat? hat;
  AvatarTop? top;
  AvatarGlasses? glasses;
  AvatarCostume? costume;
  AvatarSpecials? specials;

  AvatarConfig build() {
    return AvatarConfig(
      background: background,
      hat: hat,
      top: top,
      glasses: glasses,
      costume: costume,
      specials: specials,
    );
  }
}
