// ignore-l10n: debug — the UI lab is debug-only; its strings are hardcoded.
import 'package:flutter/material.dart';

import '../../../../core/design/components/components.dart';
import '../../../../core/design/design.dart';
import '../../../../core/models/avatar_scene.dart';

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
  };

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      LabCaptionVariant.storyline => _StageLine(
        text: sampleFor(scene),
        style: context.text.headlineSmall?.copyWith(height: 1.22),
        align: TextAlign.start,
      ),
      LabCaptionVariant.subtitle => _StageLine(
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

/// Caption text straight on the stage, kept legible by a soft halo in the
/// look's ink.
class _StageLine extends StatelessWidget {
  const _StageLine({
    required this.text,
    required this.style,
    required this.align,
  });

  final String text;
  final TextStyle? style;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final Color ink = context.tokens.background;
    return _BalancedText(
      text,
      align: align,
      style: style?.copyWith(
        color: context.colors.onSurface,
        shadows: <Shadow>[
          Shadow(color: ink.withValues(alpha: 0.9), blurRadius: 18),
          Shadow(color: ink.withValues(alpha: 0.7), blurRadius: 4),
        ],
      ),
    );
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
      child: _BalancedText(
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

/// Two lines max, broken evenly: when the text needs two lines it takes the
/// narrowest width that still fits in two, so the second line is never a
/// lone word.
class _BalancedText extends StatelessWidget {
  const _BalancedText(this.text, {required this.align, required this.style});

  final String text;
  final TextAlign align;
  final TextStyle? style;

  static const int _maxLines = 2;

  int _lines(TextPainter painter, double width) {
    painter.layout(maxWidth: width);
    return painter.computeLineMetrics().length;
  }

  double _balancedWidth(BuildContext context, double maxWidth) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    try {
      if (_lines(painter, maxWidth) != _maxLines) {
        return maxWidth;
      }
      double low = maxWidth / 2;
      double high = maxWidth;
      while (high - low > 1) {
        final double mid = (low + high) / 2;
        if (_lines(painter, mid) <= _maxLines) {
          high = mid;
        } else {
          low = mid;
        }
      }
      return high.ceilToDouble();
    } finally {
      painter.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget child = Text(
          text,
          maxLines: _maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: style,
        );
        if (!constraints.hasBoundedWidth) {
          return child;
        }
        return Align(
          alignment: align == TextAlign.center
              ? Alignment.center
              : AlignmentDirectional.centerStart,
          widthFactor: 1,
          child: SizedBox(
            width: _balancedWidth(context, constraints.maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
