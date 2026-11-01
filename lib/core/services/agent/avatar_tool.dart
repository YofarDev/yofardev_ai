import '../../models/app_lifecycle_event.dart';
import '../../models/avatar_config.dart';
import '../../models/avatar_scene.dart';
import '../../models/function_info.dart';
import 'agent_tool.dart';
import '../app_lifecycle_service.dart';
import '../../utils/logger.dart';

/// Agent tool that allows the LLM to change the avatar's appearance
/// including scene, clothes (hat, top), glasses, and accessories.
///
/// Every parameter's option list is generated from the Dart enums, so the
/// schema can never drift from what the app actually supports (the v3 lists
/// were hand-written and offered values that don't exist).
class AvatarTool extends AgentTool {
  AvatarTool(this._appLifecycleService);

  final AppLifecycleService _appLifecycleService;

  @override
  String get name => 'change_avatar';

  @override
  String get description =>
      'Changes the avatar appearance. '
      'Can change scene (background), hat, top (shirt), the colour of the top '
      'or hat (topTint, hatTint), glasses, or costume. '
      'All parameters are optional - only include the ones you want to change.';

  @override
  List<Parameter> get parameters => <Parameter>[
    Parameter(
      name: 'background',
      description: 'Scene. Options: ${_options(AvatarScene.values)}',
      type: 'string',
      isRequired: false,
    ),
    Parameter(
      name: 'hat',
      description: 'Hat/headwear. Options: ${_options(AvatarHat.values)}',
      type: 'string',
      isRequired: false,
    ),
    Parameter(
      name: 'top',
      description: 'Top/shirt. Options: ${_options(AvatarTop.values)}',
      type: 'string',
      isRequired: false,
    ),
    Parameter(
      name: 'topTint',
      description:
          'Colour variant of the top (keeps its shading; none = as drawn; '
          'ignored while a costume is worn). '
          'Options: ${_options(AvatarTint.values)}',
      type: 'string',
      isRequired: false,
    ),
    Parameter(
      name: 'hatTint',
      description:
          'Colour variant of the hat (none = as drawn; ignored while a '
          'costume is worn). Options: ${_options(AvatarTint.values)}',
      type: 'string',
      isRequired: false,
    ),
    Parameter(
      name: 'glasses',
      description: 'Eyewear. Options: ${_options(AvatarGlasses.values)}',
      type: 'string',
      isRequired: false,
    ),
    Parameter(
      name: 'costume',
      description:
          'Special costume. Options: ${_options(AvatarCostume.values)}',
      type: 'string',
      isRequired: false,
    ),
    Parameter(
      name: 'specials',
      description:
          'Presence effect. Options: ${_options(AvatarSpecials.values)}',
      type: 'string',
      isRequired: false,
    ),
  ];

  static String _options(List<Enum> values) =>
      values.map((Enum value) => value.name).join(', ');

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
        final AvatarScene? background = parseEnumName(
          AvatarScene.values,
          backgroundStr,
        );
        if (background == null) {
          return 'Error: Invalid background "$backgroundStr". '
              'Valid options: ${_options(AvatarScene.values)}';
        }
        configBuilder.background = background;
      }

      // Parse hat if provided
      final String? hatStr = args['hat'] as String?;
      if (hatStr != null) {
        final AvatarHat? hat = parseEnumName(AvatarHat.values, hatStr);
        if (hat == null) {
          return 'Error: Invalid hat "$hatStr". '
              'Valid options: ${_options(AvatarHat.values)}';
        }
        configBuilder.hat = hat;
      }

      // Parse top if provided
      final String? topStr = args['top'] as String?;
      if (topStr != null) {
        final AvatarTop? top = parseEnumName(AvatarTop.values, topStr);
        if (top == null) {
          return 'Error: Invalid top "$topStr". '
              'Valid options: ${_options(AvatarTop.values)}';
        }
        configBuilder.top = top;
      }

      // Parse the tints if provided
      final String? topTintStr = args['topTint'] as String?;
      if (topTintStr != null) {
        final AvatarTint? tint = parseEnumName(AvatarTint.values, topTintStr);
        if (tint == null) {
          return 'Error: Invalid topTint "$topTintStr". '
              'Valid options: ${_options(AvatarTint.values)}';
        }
        configBuilder.topTint = tint;
      }
      final String? hatTintStr = args['hatTint'] as String?;
      if (hatTintStr != null) {
        final AvatarTint? tint = parseEnumName(AvatarTint.values, hatTintStr);
        if (tint == null) {
          return 'Error: Invalid hatTint "$hatTintStr". '
              'Valid options: ${_options(AvatarTint.values)}';
        }
        configBuilder.hatTint = tint;
      }

      // Parse glasses if provided
      final String? glassesStr = args['glasses'] as String?;
      if (glassesStr != null) {
        final AvatarGlasses? glasses = parseEnumName(
          AvatarGlasses.values,
          glassesStr,
        );
        if (glasses == null) {
          return 'Error: Invalid glasses "$glassesStr". '
              'Valid options: ${_options(AvatarGlasses.values)}';
        }
        configBuilder.glasses = glasses;
      }

      // Parse costume if provided
      final String? costumeStr = args['costume'] as String?;
      if (costumeStr != null) {
        final AvatarCostume? costume = parseEnumName(
          AvatarCostume.values,
          costumeStr,
        );
        if (costume == null) {
          return 'Error: Invalid costume "$costumeStr". '
              'Valid options: ${_options(AvatarCostume.values)}';
        }
        configBuilder.costume = costume;
      }

      // Parse specials if provided
      final String? specialsStr = args['specials'] as String?;
      if (specialsStr != null) {
        final AvatarSpecials? specials = parseEnumName(
          AvatarSpecials.values,
          specialsStr,
        );
        if (specials == null) {
          return 'Error: Invalid special effect "$specialsStr". '
              'Valid options: ${_options(AvatarSpecials.values)}';
        }
        configBuilder.specials = specials;
      }

      // Check if any changes were requested
      if (backgroundStr == null &&
          hatStr == null &&
          topStr == null &&
          topTintStr == null &&
          hatTintStr == null &&
          glassesStr == null &&
          costumeStr == null &&
          specialsStr == null) {
        return 'Error: No avatar changes requested. '
            'Please specify at least one parameter to change (background, hat, top, topTint, hatTint, glasses, costume, or specials).';
      }

      // Build the config
      final AvatarConfig newConfig = configBuilder.build();

      AppLogger.debug(
        'AvatarTool: newConfig=$newConfig, background=${newConfig.background}, top=${newConfig.top}, hat=${newConfig.hat}',
        tag: 'AvatarTool',
      );

      // Determine which animation to use based on what changed
      // Scene changes use leaveAndComeBack animation
      // Clothes changes use outOfScreen animation (go down and up)
      final bool backgroundChanged = backgroundStr != null;
      final bool clothesChanged =
          hatStr != null ||
          topStr != null ||
          topTintStr != null ||
          hatTintStr != null ||
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

      AppLogger.debug(
        'AvatarTool: emitting avatarChangeRequested (configWithAnimation=$configWithAnimation)',
        tag: 'AvatarTool',
      );
      _appLifecycleService.emitAvatarChangeRequested(
        AvatarChangeRequested(
          newConfig: newConfig,
          configWithAnimation: configWithAnimation,
          backgroundOnly:
              backgroundStr != null &&
              hatStr == null &&
              topStr == null &&
              topTintStr == null &&
              hatTintStr == null &&
              glassesStr == null &&
              costumeStr == null &&
              specialsStr == null,
        ),
      );
      AppLogger.debug(
        'AvatarTool: emitAvatarChangeRequested called successfully',
        tag: 'AvatarTool',
      );

      // Generate success message
      final List<String> changes = <String>[];
      if (backgroundStr != null) changes.add('background to $backgroundStr');
      if (hatStr != null) changes.add('hat to $hatStr');
      if (topStr != null) changes.add('top to $topStr');
      if (topTintStr != null) changes.add('top tint to $topTintStr');
      if (hatTintStr != null) changes.add('hat tint to $hatTintStr');
      if (glassesStr != null) changes.add('glasses to $glassesStr');
      if (costumeStr != null) changes.add('costume to $costumeStr');
      if (specialsStr != null) changes.add('special effects to $specialsStr');

      return 'Successfully changed ${changes.join(', ')}.';
    } catch (e) {
      return 'Error changing avatar: $e';
    }
  }
}

/// Case/underscore-tolerant enum lookup by name (e.g. "pink hoodie" finds
/// `pinkHoodie`).
T? parseEnumName<T extends Enum>(List<T> values, String value) {
  final String normalized = value.toLowerCase().replaceAll(' ', '_');
  for (final T candidate in values) {
    if (candidate.name.toLowerCase() == normalized) {
      return candidate;
    }
  }
  return null;
}

/// Helper class to build AvatarConfig with optional fields
class AvatarConfigBuilder {
  AvatarScene? background;
  AvatarHat? hat;
  AvatarTop? top;
  AvatarTint? topTint;
  AvatarTint? hatTint;
  AvatarGlasses? glasses;
  AvatarCostume? costume;
  AvatarSpecials? specials;

  AvatarConfig build() {
    return AvatarConfig(
      background: background,
      hat: hat,
      top: top,
      topTint: topTint,
      hatTint: hatTint,
      glasses: glasses,
      costume: costume,
      specials: specials,
    );
  }
}
