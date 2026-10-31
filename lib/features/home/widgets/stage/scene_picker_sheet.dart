import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/components/components.dart';
import '../../../../core/design/components/interactive_surface.dart';
import '../../../../core/design/design.dart';
import '../../../../core/design/looks/looks.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/models/app_lifecycle_event.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/avatar_scene.dart';
import '../../../../core/services/app_lifecycle_service.dart';
import '../../../avatar/avatar.dart';

/// The change request a scene pick emits: the same one the `change_avatar`
/// tool emits for a background-only change, so it runs the journey and is
/// saved with the chat.
AvatarChangeRequested sceneChangeRequest(AvatarScene scene) {
  final AvatarConfig newConfig = AvatarConfig(background: scene);
  return AvatarChangeRequested(
    newConfig: newConfig,
    configWithAnimation: newConfig.copyWith(
      specials: AvatarSpecials.leaveAndComeBack,
    ),
    backgroundOnly: true,
  );
}

/// The localized name of [scene].
String sceneName(AppLocalizations l10n, AvatarScene scene) => switch (scene) {
  AvatarScene.livingRoom => l10n.sceneLivingRoom,
  AvatarScene.campfire => l10n.sceneCampfire,
  AvatarScene.beach => l10n.sceneBeach,
  AvatarScene.deepSpace => l10n.sceneDeepSpace,
  AvatarScene.cafe => l10n.sceneCafe,
  AvatarScene.rooftop => l10n.sceneRooftop,
  AvatarScene.mountainHut => l10n.sceneMountainHut,
  AvatarScene.forestCabin => l10n.sceneForestCabin,
  AvatarScene.trainCompartment => l10n.sceneTrainCompartment,
  AvatarScene.library => l10n.sceneLibrary,
};

/// A glass bottom sheet with one tile per scene: its poster and localized
/// name, the scene on screen marked. Picking another scene emits
/// [sceneChangeRequest] through [lifecycle] and closes the sheet; every tile
/// is disabled while a journey runs. Needs an [AvatarCubit] above it (see
/// [show]).
class ScenePickerSheet extends StatelessWidget {
  const ScenePickerSheet({super.key, required this.lifecycle, this.onPicked});

  final AppLifecycleService lifecycle;

  /// Called after a pick (the sheet closes itself).
  final VoidCallback? onPicked;

  /// Opens the sheet over [context]'s navigator. The sheet is a new route, so
  /// the [AvatarCubit] is handed over explicitly.
  static Future<void> show(
    BuildContext context, {
    required AppLifecycleService lifecycle,
    VoidCallback? onPicked,
  }) {
    final AvatarCubit avatar = context.read<AvatarCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (BuildContext sheetContext) => BlocProvider<AvatarCubit>.value(
        value: avatar,
        child: ScenePickerSheet(lifecycle: lifecycle, onPicked: onPicked),
      ),
    );
  }

  void _pick(BuildContext context, AvatarScene scene) {
    onPicked?.call();
    lifecycle.emitAvatarChangeRequested(sceneChangeRequest(scene));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocSelector<
      AvatarCubit,
      AvatarState,
      ({AvatarScene scene, bool traveling})
    >(
      selector: (AvatarState state) =>
          (scene: state.scene, traveling: state.journey != null),
      builder:
          (BuildContext context, ({AvatarScene scene, bool traveling}) now) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.sm,
                0,
                AppSpace.sm,
                AppSpace.sm,
              ),
              child: GlassPanel(
                level: AppGlassLevel.thick,
                blur: true,
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.md,
                  AppSpace.lg,
                  AppSpace.lg,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.scenePickerTitle,
                          style: context.text.titleLarge,
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: AppSpace.sm,
                        crossAxisSpacing: AppSpace.sm,
                        childAspectRatio: 0.72,
                        children: <Widget>[
                          for (final AvatarScene scene in AvatarScene.values)
                            _SceneTile(
                              scene: scene,
                              label: sceneName(l10n, scene),
                              current: scene == now.scene,
                              enabled: !now.traveling,
                              onTap: () => _pick(context, scene),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
    );
  }
}

class _SceneTile extends StatelessWidget {
  const _SceneTile({
    required this.scene,
    required this.label,
    required this.current,
    required this.enabled,
    required this.onTap,
  });

  final AvatarScene scene;
  final String label;
  final bool current;
  final bool enabled;
  final VoidCallback onTap;

  static String posterPath(AvatarScene scene) =>
      'assets/rive/posters/${scene.name}.webp';

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color accent = tokens.scene.accent;
    final BorderRadius radius = BorderRadius.circular(
      tokens.radius(AppRadius.md),
    );
    // The scene's own accent, for a poster that is not bundled (yet).
    final Color sceneAccent = UiLooks.storybook.palette(scene).accent;
    final VoidCallback? tap = enabled && !current ? onTap : null;
    return InteractiveSurface(
      onTap: tap,
      builder: (BuildContext context, InteractiveStates states) {
        final bool lifted = states.hovered || states.focused || states.pressed;
        return Semantics(
          button: true,
          selected: current,
          enabled: enabled,
          focusable: tap != null,
          focused: states.focused,
          label: label,
          onTap: tap,
          excludeSemantics: true,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: current || states.focused
                      ? accent
                      : tokens.glassBorder.withValues(
                          alpha: lifted ? 0.8 : 0.4,
                        ),
                  width: current ? 2 : tokens.outlineWidth,
                ),
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.asset(
                      posterPath(scene),
                      fit: BoxFit.cover,
                      cacheWidth: 360,
                      excludeFromSemantics: true,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) => ColoredBox(
                            key: ValueKey<String>(
                              'poster-fallback-${scene.name}',
                            ),
                            color: sceneAccent.withValues(alpha: 0.35),
                          ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              tokens.background.withValues(alpha: 0),
                              tokens.background.withValues(alpha: 0.9),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpace.xs,
                            AppSpace.lg,
                            AppSpace.xs,
                            AppSpace.sm,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: Text(
                              label,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelLarge?.copyWith(
                                color: context.colors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (current)
                      Positioned(
                        top: AppSpace.xs,
                        right: AppSpace.xs,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: tokens.scene.onAccent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
