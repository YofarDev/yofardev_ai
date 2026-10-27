// ignore-l10n: debug — the UI lab is debug-only; its strings are hardcoded.
import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/design/looks/looks.dart';
import '../../../../core/models/avatar_scene.dart';

/// Which Home layout the lab's Stage tab shows.
enum LabLayout { stageChips, dock, curtain }

/// Which composer state the lab's Stage tab shows.
enum LabComposerState { idle, typing, listening, thinking, speaking }

/// Which lab tab is open.
enum LabTab { stage, surfaces }

const Object _keep = Object();

/// Everything the UI lab can vary. Immutable; the lab owns a
/// `ValueNotifier<LabConfig>` and the debug service extensions edit it.
@immutable
class LabConfig {
  const LabConfig({
    required this.lookId,
    required this.scene,
    required this.layout,
    required this.composer,
    required this.tab,
    this.accentHueOverride,
    this.glassAlphaScale = 1,
    this.radiusScaleOverride,
  });

  /// The lab's starting point.
  static const LabConfig initial = LabConfig(
    lookId: 'neon',
    scene: AvatarScene.livingRoom,
    layout: LabLayout.stageChips,
    composer: LabComposerState.idle,
    tab: LabTab.surfaces,
  );

  /// The id of one of [UiLooks.all].
  final String lookId;
  final AvatarScene scene;
  final LabLayout layout;
  final LabComposerState composer;
  final LabTab tab;

  /// Hue (degrees, 0..360) replacing the scene accent's hue; null keeps it.
  final double? accentHueOverride;

  /// Multiplier of the glass fill alphas (1 = the look's own).
  final double glassAlphaScale;

  /// Replaces the look's radius scale; null keeps it.
  final double? radiusScaleOverride;

  static const double maxGlassAlphaScale = 4;
  static const double maxRadiusScale = 3;

  /// The look named by [lookId].
  UiLook get look => UiLooks.all.firstWhere(
    (UiLook l) => l.id == lookId,
    orElse: () {
      throw StateError('Unknown look id "$lookId"');
    },
  );

  /// Copy with the given fields replaced. Pass `null` explicitly to clear
  /// [accentHueOverride] or [radiusScaleOverride].
  LabConfig copyWith({
    String? lookId,
    AvatarScene? scene,
    LabLayout? layout,
    LabComposerState? composer,
    LabTab? tab,
    Object? accentHueOverride = _keep,
    double? glassAlphaScale,
    Object? radiusScaleOverride = _keep,
  }) {
    return LabConfig(
      lookId: lookId ?? this.lookId,
      scene: scene ?? this.scene,
      layout: layout ?? this.layout,
      composer: composer ?? this.composer,
      tab: tab ?? this.tab,
      accentHueOverride: identical(accentHueOverride, _keep)
          ? this.accentHueOverride
          : (accentHueOverride as num?)?.toDouble(),
      glassAlphaScale: glassAlphaScale ?? this.glassAlphaScale,
      radiusScaleOverride: identical(radiusScaleOverride, _keep)
          ? this.radiusScaleOverride
          : (radiusScaleOverride as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'lookId': lookId,
    'scene': scene.name,
    'layout': layout.name,
    'composer': composer.name,
    'tab': tab.name,
    'accentHueOverride': accentHueOverride,
    'glassAlphaScale': glassAlphaScale,
    'radiusScaleOverride': radiusScaleOverride,
  };

  static const Set<String> _keys = <String>{
    'lookId',
    'scene',
    'layout',
    'composer',
    'tab',
    'accentHueOverride',
    'glassAlphaScale',
    'radiusScaleOverride',
  };

  /// Parses [json]. Missing keys take the [initial] values; unknown keys,
  /// unknown enum names, wrong types and out-of-range numbers throw a
  /// [FormatException].
  static LabConfig fromJson(Map<String, Object?> json) {
    for (final String key in json.keys) {
      if (!_keys.contains(key)) {
        throw FormatException('Unknown key "$key"');
      }
    }
    final String lookId = json.containsKey('lookId')
        ? _string(json, 'lookId')
        : initial.lookId;
    if (!UiLooks.all.any((UiLook l) => l.id == lookId)) {
      throw FormatException(
        'Unknown lookId "$lookId" (${UiLooks.all.map((UiLook l) => l.id).join(', ')})',
      );
    }
    return LabConfig(
      lookId: lookId,
      scene: _enum(json, 'scene', AvatarScene.values, initial.scene),
      layout: _enum(json, 'layout', LabLayout.values, initial.layout),
      composer: _enum(
        json,
        'composer',
        LabComposerState.values,
        initial.composer,
      ),
      tab: _enum(json, 'tab', LabTab.values, initial.tab),
      accentHueOverride: _optionalNumber(json, 'accentHueOverride', 0, 360),
      glassAlphaScale: json.containsKey('glassAlphaScale')
          ? _number(json, 'glassAlphaScale', 0, maxGlassAlphaScale)
          : initial.glassAlphaScale,
      radiusScaleOverride: _optionalNumber(
        json,
        'radiusScaleOverride',
        0,
        maxRadiusScale,
      ),
    );
  }

  static String _string(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! String) {
      throw FormatException('"$key" must be a string, got $value');
    }
    return value;
  }

  static T _enum<T extends Enum>(
    Map<String, Object?> json,
    String key,
    List<T> values,
    T fallback,
  ) {
    if (!json.containsKey(key)) {
      return fallback;
    }
    final String name = _string(json, key);
    for (final T value in values) {
      if (value.name == name) {
        return value;
      }
    }
    throw FormatException(
      'Unknown $key "$name" (${values.map((T v) => v.name).join(', ')})',
    );
  }

  static double _number(
    Map<String, Object?> json,
    String key,
    double min,
    double max,
  ) {
    final Object? value = json[key];
    if (value is! num || !value.isFinite) {
      throw FormatException('"$key" must be a number, got $value');
    }
    if (value < min || value > max) {
      throw FormatException('"$key" must be within $min..$max, got $value');
    }
    return value.toDouble();
  }

  static double? _optionalNumber(
    Map<String, Object?> json,
    String key,
    double min,
    double max,
  ) {
    if (json[key] == null) {
      return null;
    }
    return _number(json, key, min, max);
  }

  @override
  bool operator ==(Object other) =>
      other is LabConfig &&
      other.lookId == lookId &&
      other.scene == scene &&
      other.layout == layout &&
      other.composer == composer &&
      other.tab == tab &&
      other.accentHueOverride == accentHueOverride &&
      other.glassAlphaScale == glassAlphaScale &&
      other.radiusScaleOverride == radiusScaleOverride;

  @override
  int get hashCode => Object.hash(
    lookId,
    scene,
    layout,
    composer,
    tab,
    accentHueOverride,
    glassAlphaScale,
    radiusScaleOverride,
  );

  @override
  String toString() => 'LabConfig(${toJson()})';
}

const Color _black = Color(0xFF000000);
const Color _white = Color(0xFFFFFFFF);
const double _minOnAccentContrast = 4.5;
const double _glowAlpha = 0.35;

Color _onAccentFor(Color accent, Color ink) {
  for (final Color candidate in <Color>[ink, _black]) {
    if (contrastRatio(candidate, accent) >= _minOnAccentContrast) {
      return candidate;
    }
  }
  return _white;
}

AppGlassStyle _scaleFill(AppGlassStyle style, double scale) => AppGlassStyle(
  blurSigma: style.blurSigma,
  fillAlpha: (style.fillAlpha * scale).clamp(0.0, 1.0),
  borderAlpha: style.borderAlpha,
);

/// Applies the lab's manual overrides on top of a look [base] theme: the
/// accent hue (saturation and value kept; `onAccent`, glow and the color
/// scheme's primary/secondary follow), the glass fill alpha scale and the
/// radius scale. Returns [base] itself when nothing is overridden.
///
/// Component themes already baked into [base] (radio, icon button, ...) keep
/// the original accent; the kit components read the tokens and so follow.
ThemeData applyLabOverrides(ThemeData base, LabConfig config) {
  final double? hue = config.accentHueOverride;
  final double? radius = config.radiusScaleOverride;
  final double glassScale = config.glassAlphaScale;
  if (hue == null && radius == null && glassScale == 1) {
    return base;
  }
  final AppTokens? tokens = base.extension<AppTokens>();
  if (tokens == null) {
    throw StateError('applyLabOverrides needs a theme built with AppTokens');
  }

  ScenePalette scene = tokens.scene;
  ColorScheme scheme = base.colorScheme;
  if (hue != null) {
    final Color accent = HSVColor.fromColor(
      tokens.scene.accent,
    ).withHue(hue).toColor();
    final Color onAccent = _onAccentFor(accent, tokens.background);
    final Color container = Color.alphaBlend(
      accent.withValues(alpha: 0.25),
      scheme.surface,
    );
    scene = ScenePalette(
      accent: accent,
      onAccent: onAccent,
      glow: accent.withValues(alpha: _glowAlpha),
    );
    scheme = scheme.copyWith(
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: container,
      secondary: accent,
      onSecondary: onAccent,
      secondaryContainer: container,
      tertiary: accent,
    );
  }

  final AppTokens overridden = tokens.copyWith(
    scene: scene,
    glassThin: _scaleFill(tokens.glassThin, glassScale),
    glassRegular: _scaleFill(tokens.glassRegular, glassScale),
    glassThick: _scaleFill(tokens.glassThick, glassScale),
    radiusScale: radius ?? tokens.radiusScale,
  );
  final List<ThemeExtension<dynamic>> extensions =
      base.extensions.values
          .where((ThemeExtension<dynamic> e) => e is! AppTokens)
          .toList()
        ..add(overridden);
  return base.copyWith(colorScheme: scheme, extensions: extensions);
}
