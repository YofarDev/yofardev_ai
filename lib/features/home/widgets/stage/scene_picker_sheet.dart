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
/// name, the scene on screen marked. Three columns, two from a text scale of
/// [largeTextScale] (M11 ruling 19: the names wrap to two lines).
///
/// For a screen reader every tile is a button with the scene's name, the
/// scene on screen selected with a "current scene" hint (M11 ruling 20). Picking another scene emits
/// [sceneChangeRequest] through [lifecycle] and closes the sheet; every tile
/// is disabled while a journey runs. Needs an [AvatarCubit] above it (see
/// [show]).
class ScenePickerSheet extends StatelessWidget {
  const ScenePickerSheet({super.key, required this.lifecycle, this.onPicked});

  final AppLifecycleService lifecycle;

  /// Called after a pick (the sheet closes itself).
  final VoidCallback? onPicked;

  /// From this text scale on, the grid has two columns, not three.
  static const double largeTextScale = 1.5;

  /// Below this screen width the grid has two columns too (a three-column
  /// tile would cut "Train compartment").
  static const double narrowWidth = 375;

  /// The grid's columns at [textScale] (`TextScaler.scale(1)`) on a screen
  /// [width] wide.
  static int columnsFor(double textScale, double width) =>
      textScale >= largeTextScale || width < narrowWidth ? 2 : 3;

  /// A tile name's lines at [textScale]: two, three from 2.0 (a long word
  /// such as "Compartiment" then needs its own line on a narrow phone).
  static int nameLinesFor(double textScale) => textScale >= 2 ? 3 : 2;

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
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    final int columns = columnsFor(textScale, MediaQuery.sizeOf(context).width);
    final int nameLines = nameLinesFor(textScale);
    // Taller tiles under large text: the name takes up to [nameLines].
    final double aspect = textScale >= 2
        ? 0.56
        : textScale >= largeTextScale
        ? 0.66
        : 0.72;
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
                        crossAxisCount: columns,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: AppSpace.sm,
                        crossAxisSpacing: AppSpace.sm,
                        childAspectRatio: aspect,
                        children: <Widget>[
                          for (final AvatarScene scene in AvatarScene.values)
                            _SceneTile(
                              key: ValueKey<String>('scene-tile-${scene.name}'),
                              scene: scene,
                              currentHint: l10n.scenePickerCurrentHint,
                              nameLines: nameLines,
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
    super.key,
    required this.scene,
    required this.currentHint,
    required this.nameLines,
    required this.label,
    required this.current,
    required this.enabled,
    required this.onTap,
  });

  final AvatarScene scene;
  final String label;

  /// Read after the name on the scene on screen.
  final String currentHint;

  /// The name's lines at most.
  final int nameLines;
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
          hint: current ? currentHint : null,
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
                              maxLines: nameLines,
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
