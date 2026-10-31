// ignore-l10n: debug — the UI lab is debug-only; its strings are hardcoded.
import 'package:flutter/material.dart';

import '../../../../core/design/components/components.dart';
import '../../../../core/design/design.dart';
import '../../../../core/models/avatar_scene.dart';
import '../stage/stage_line.dart';

/// How a [LabCaption] sits on the stage.
enum LabCaptionVariant {
  /// Large, left-aligned display type above the composer (layout L1).
  storyline,

  /// Centred, film-subtitle style line above the dock (layout L2).
  subtitle,

  /// A speech bubble near the character's head (layout L3).
  bubble,
}

/// What the character just said, in the look's display font, two lines max.
/// The sample sentence depends on the scene.
class LabCaption extends StatelessWidget {
  const LabCaption({
    super.key,
    required this.scene,
    this.variant = LabCaptionVariant.storyline,
    this.tailAt = 0.5,
  });

  final AvatarScene scene;
  final LabCaptionVariant variant;

  /// Horizontal position (0..1 of the bubble width) of the bubble's tail.
  final double tailAt;

  /// One line per scene, in the character's voice. Each fits two lines of
  /// the widest caption style at phone width (see lab_caption_fit_test).
  static String sampleFor(AvatarScene scene) => switch (scene) {
    AvatarScene.livingRoom => 'The cat thinks the lamp is a second moon.',
    AvatarScene.campfire => 'Marshmallow number four. The owl is counting.',
    AvatarScene.beach => 'That crab keeps side-eyeing my sandwich.',
    AvatarScene.deepSpace => 'Out here, my rubber duck has its own orbit.',
    AvatarScene.cafe => 'The goldfish judges every croissant I order.',
    AvatarScene.rooftop => 'That pigeon owns this roof. I just pay rent.',
    AvatarScene.mountainHut => 'The dog snores louder than the stove crackles.',
    AvatarScene.forestCabin => 'The squirrel left me one acorn. Very generous.',
    AvatarScene.trainCompartment =>
      'A ladybug bought the cheapest ticket on board.',
    AvatarScene.library => 'The mouse has read every book on the bottom shelf.',
  };

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      LabCaptionVariant.storyline => StageLine(
        text: sampleFor(scene),
        style: context.text.headlineSmall?.copyWith(height: 1.22),
        align: TextAlign.start,
      ),
      LabCaptionVariant.subtitle => StageLine(
        text: sampleFor(scene),
        style: context.text.titleLarge?.copyWith(fontSize: 19, height: 1.32),
        align: TextAlign.center,
      ),
      LabCaptionVariant.bubble => _Bubble(
        text: sampleFor(scene),
        tailAt: tailAt,
      ),
    };
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.tailAt});

  final String text;
  final double tailAt;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      level: AppGlassLevel.thick,
      blur: true,
      shape: SpeechBubbleBorder(
        radius: context.tokens.radius(AppRadius.lg),
        tailAt: tailAt,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.md,
        AppSpace.lg,
        AppSpace.md + SpeechBubbleBorder.tailHeight,
      ),
      child: BalancedText(
        text,
        align: TextAlign.start,
        style: context.text.titleMedium?.copyWith(
          fontSize: 17,
          height: 1.3,
          color: context.colors.onSurface,
        ),
      ),
    );
  }
}
