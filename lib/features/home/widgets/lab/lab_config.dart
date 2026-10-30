// ignore-l10n: debug — the UI lab is debug-only; its strings are hardcoded.
import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/models/avatar_mood.dart';
import '../../../../core/models/avatar_scene.dart';
import '../../../../core/models/performance/performance.dart';
import '../../../avatar/avatar.dart';

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
    required this.scene,
    required this.layout,
    required this.composer,
    required this.tab,
    this.accentHueOverride,
    this.glassAlphaScale = 1,
    this.radiusScaleOverride,
    this.panelCollapsed = false,
    this.face,
    this.prop = AvatarProp.none,
    this.parallax,
    this.shot = Shot.wide,
    this.npc,
  });

  /// The lab's starting point.
  static const LabConfig initial = LabConfig(
    scene: AvatarScene.livingRoom,
    layout: LabLayout.stageChips,
    composer: LabComposerState.idle,
    tab: LabTab.stage,
  );

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

  /// Whether the lab's controls panel is folded away, leaving the preview
  /// the whole screen (bar the tab row).
  final bool panelCollapsed;

  /// A hand-set face shown on the stage avatar instead of the live one;
  /// null shows the live face. See [LabFace].
  final FaceFrame? face;

  /// The prop the stage avatar holds (contract v7 `prop`).
  final AvatarProp prop;

  /// A hand-set scene parallax offset (contract v7, each axis -1..1); null
  /// leaves the scene to the live source.
  final Offset? parallax;

  /// The camera framing of the stage, cut to by hand (moonshot M7).
  final Shot shot;

  /// A hand-set scene NPC pose (contract v11 `npc`, `npcX`, `npcLook`); null
  /// leaves the NPC at rest.
  final NpcIntent? npc;

  static const double maxGlassAlphaScale = 4;
  static const double maxRadiusScale = 3;

  /// Copy with the given fields replaced. Pass `null` explicitly to clear
  /// [accentHueOverride], [radiusScaleOverride], [face], [parallax] or
  /// [npc].
  LabConfig copyWith({
    AvatarScene? scene,
    LabLayout? layout,
    LabComposerState? composer,
    LabTab? tab,
    Object? accentHueOverride = _keep,
    double? glassAlphaScale,
    Object? radiusScaleOverride = _keep,
    bool? panelCollapsed,
    Object? face = _keep,
    AvatarProp? prop,
    Object? parallax = _keep,
    Shot? shot,
    Object? npc = _keep,
  }) {
    return LabConfig(
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
      panelCollapsed: panelCollapsed ?? this.panelCollapsed,
      face: identical(face, _keep) ? this.face : face as FaceFrame?,
      prop: prop ?? this.prop,
      parallax: identical(parallax, _keep)
          ? this.parallax
          : parallax as Offset?,
      shot: shot ?? this.shot,
      npc: identical(npc, _keep) ? this.npc : npc as NpcIntent?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'scene': scene.name,
    'layout': layout.name,
    'composer': composer.name,
    'tab': tab.name,
    'accentHueOverride': accentHueOverride,
    'glassAlphaScale': glassAlphaScale,
    'radiusScaleOverride': radiusScaleOverride,
    'panelCollapsed': panelCollapsed,
    'face': face == null ? null : LabFace.toJson(face!),
    'prop': prop.name,
    'parallax': parallax == null
        ? null
        : <String, double>{'x': parallax!.dx, 'y': parallax!.dy},
    'shot': shot.name,
    'npc': npc == null
        ? null
        : <String, Object>{
            'npc': npc!.npc.name,
            'npcX': npc!.npcX,
            'npcLook': npc!.npcLook,
          },
  };

  static const Set<String> _keys = <String>{
    'scene',
    'layout',
    'composer',
    'tab',
    'accentHueOverride',
    'glassAlphaScale',
    'radiusScaleOverride',
    'panelCollapsed',
    'face',
    'prop',
    'parallax',
    'shot',
    'npc',
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
    return LabConfig(
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
      panelCollapsed: json.containsKey('panelCollapsed')
          ? _bool(json, 'panelCollapsed')
          : initial.panelCollapsed,
      face: json['face'] == null ? null : LabFace.fromJson(json['face']),
      prop: _enum(json, 'prop', AvatarProp.values, initial.prop),
      parallax: json['parallax'] == null ? null : _parallax(json['parallax']),
      shot: _enum(json, 'shot', Shot.values, initial.shot),
      npc: json['npc'] == null ? null : _npc(json['npc']),
    );
  }

  /// Parses the `npc` object: `npc` (a state name, default rest), `npcX`
  /// (0..1) and `npcLook` (−1..1), each optional (0); anything else throws a
  /// [FormatException].
  static NpcIntent _npc(Object? value) {
    if (value is! Map<String, Object?>) {
      throw FormatException('"npc" must be an object, got $value');
    }
    for (final String key in value.keys) {
      if (key != 'npc' && key != 'npcX' && key != 'npcLook') {
        throw FormatException('Unknown npc key "$key"');
      }
    }
    return NpcIntent(
      npc: _enum(value, 'npc', NpcState.values, NpcState.rest),
      npcX: value.containsKey('npcX') ? _number(value, 'npcX', 0, 1) : 0,
      npcLook: value.containsKey('npcLook')
          ? _number(value, 'npcLook', -1, 1)
          : 0,
    );
  }

  /// Parses the `parallax` object: `x` and `y`, each -1..1 (a missing axis
  /// is 0); anything else throws a [FormatException].
  static Offset _parallax(Object? value) {
    if (value is! Map<String, Object?>) {
      throw FormatException('"parallax" must be an object, got $value');
    }
    for (final String key in value.keys) {
      if (key != 'x' && key != 'y') {
        throw FormatException('Unknown parallax key "$key"');
      }
    }
    return Offset(
      value.containsKey('x') ? _number(value, 'x', -1, 1) : 0,
      value.containsKey('y') ? _number(value, 'y', -1, 1) : 0,
    );
  }

  static bool _bool(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! bool) {
      throw FormatException('"$key" must be true or false, got $value');
    }
    return value;
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
      other.scene == scene &&
      other.layout == layout &&
      other.composer == composer &&
      other.tab == tab &&
      other.accentHueOverride == accentHueOverride &&
      other.glassAlphaScale == glassAlphaScale &&
      other.radiusScaleOverride == radiusScaleOverride &&
      other.panelCollapsed == panelCollapsed &&
      other.face == face &&
      other.prop == prop &&
      other.parallax == parallax &&
      other.shot == shot &&
      other.npc == npc;

  @override
  int get hashCode => Object.hash(
    scene,
    layout,
    composer,
    tab,
    accentHueOverride,
    glassAlphaScale,
    radiusScaleOverride,
    panelCollapsed,
    face,
    prop,
    parallax,
    shot,
    npc,
  );

  @override
  String toString() => 'LabConfig(${toJson()})';
}

/// The lab's face controls (contract v6): every number of a lab face goes by
/// its `AvatarVM` name. A lab face never auto-blinks (a still pose for
/// screenshots) and has no nod; its `blinkSerial` is `blink` in JSON.
abstract final class LabFace {
  /// The 14 action units, 0..1.
  static const List<String> actionUnitKeys = AvatarRiveContract.actionUnitProps;

  /// The 14 per-side offsets (viewer's left, then right), −1..1.
  static const List<String> sideKeys = AvatarRiveContract.actionUnitSideProps;

  /// The speech mouth extras and the head: `lipTuck`, `tongueUp`, `breath`
  /// (0..1) and `roll` (−1..1).
  static const List<String> extraKeys = <String>[
    AvatarRiveContract.propLipTuck,
    AvatarRiveContract.propTongueUp,
    AvatarRiveContract.propRoll,
    AvatarRiveContract.propBreath,
  ];

  /// Every number of a lab face.
  static const List<String> numberKeys = <String>[
    ...actionUnitKeys,
    ...sideKeys,
    ...extraKeys,
  ];

  /// JSON key of the blink count (each increase fires one blink).
  static const String blinkKey = 'blink';

  /// The pose a lab face starts from: the live face of the lab's avatar
  /// (no performer, neutral mood).
  static const FaceFrame base = FaceFrame(autoBlink: false);

  /// The (min, max) of the number [key].
  static (double, double) range(String key) =>
      sideKeys.contains(key) || key == AvatarRiveContract.propRoll
      ? (AvatarRiveContract.sideMin, AvatarRiveContract.sideMax)
      : (AvatarRiveContract.faceMin, AvatarRiveContract.faceMax);

  /// Every number of [face], by name.
  static Map<String, double> values(FaceFrame face) {
    final ActionUnits a = face.au;
    final List<double> au = <double>[
      a.browInnerUp,
      a.browOuterUp,
      a.browLower,
      a.lidTighten,
      a.upperLidRaise,
      a.cheekRaise,
      a.noseWrinkle,
      a.lipCornerPull,
      a.lipCornerDepress,
      a.lipStretch,
      a.lipPucker,
      a.lipPress,
      a.jawDrop,
      a.dimpler,
    ];
    final List<double> sides = <double>[
      ..._sideList(face.left),
      ..._sideList(face.right),
    ];
    return <String, double>{
      for (int i = 0; i < au.length; i++) actionUnitKeys[i]: au[i],
      for (int i = 0; i < sides.length; i++) sideKeys[i]: sides[i],
      AvatarRiveContract.propLipTuck: face.lipTuck,
      AvatarRiveContract.propTongueUp: face.tongueUp,
      AvatarRiveContract.propRoll: face.roll,
      AvatarRiveContract.propBreath: face.breath,
    };
  }

  /// A lab face from [values] (missing names are 0).
  static FaceFrame fromValues(
    Map<String, double> values, {
    int blinkSerial = 0,
  }) {
    double v(String key) => values[key] ?? 0;
    final List<double> au = <double>[
      for (final String k in actionUnitKeys) v(k),
    ];
    return FaceFrame(
      au: ActionUnits(
        browInnerUp: au[0],
        browOuterUp: au[1],
        browLower: au[2],
        lidTighten: au[3],
        upperLidRaise: au[4],
        cheekRaise: au[5],
        noseWrinkle: au[6],
        lipCornerPull: au[7],
        lipCornerDepress: au[8],
        lipStretch: au[9],
        lipPucker: au[10],
        lipPress: au[11],
        jawDrop: au[12],
        dimpler: au[13],
      ),
      left: _sides(AvatarRiveContract.actionUnitLeftProps.map(v).toList()),
      right: _sides(AvatarRiveContract.actionUnitRightProps.map(v).toList()),
      lipTuck: v(AvatarRiveContract.propLipTuck),
      tongueUp: v(AvatarRiveContract.propTongueUp),
      roll: v(AvatarRiveContract.propRoll),
      breath: v(AvatarRiveContract.propBreath),
      autoBlink: false,
      blinkSerial: blinkSerial,
    );
  }

  /// [face] with the number [key] set to [value].
  static FaceFrame withValue(FaceFrame face, String key, double value) {
    if (!numberKeys.contains(key)) {
      throw ArgumentError.value(key, 'key', 'not a lab face number');
    }
    return fromValues(<String, double>{
      ...values(face),
      key: value,
    }, blinkSerial: face.blinkSerial);
  }

  /// [face] with the AU preset and side offsets of [mood] (the mouth
  /// extras, roll and breath kept).
  static FaceFrame withMood(FaceFrame face, AvatarMood mood) {
    final ({ActionUnitSides left, ActionUnitSides right}) sides = sidesForMood(
      mood,
    );
    return FaceFrame(
      au: actionUnitsForMood(mood),
      left: sides.left,
      right: sides.right,
      lipTuck: face.lipTuck,
      tongueUp: face.tongueUp,
      roll: face.roll,
      breath: face.breath,
      autoBlink: false,
      blinkSerial: face.blinkSerial,
    );
  }

  /// Whether [face] wears [mood]'s AU preset and side offsets.
  static bool hasMood(FaceFrame face, AvatarMood mood) {
    final ({ActionUnitSides left, ActionUnitSides right}) sides = sidesForMood(
      mood,
    );
    return face.au == actionUnitsForMood(mood) &&
        face.left == sides.left &&
        face.right == sides.right;
  }

  /// [face] with [viseme]'s mouth shape: the jaw, pucker, stretch and press
  /// AUs, `lipTuck` and `tongueUp` (every other number kept).
  static FaceFrame withViseme(FaceFrame face, Viseme viseme) {
    final MouthShape m = MouthShape.forViseme(viseme);
    return FaceFrame(
      au: face.au.copyWith(
        jawDrop: m.jaw,
        lipPucker: m.pucker,
        lipStretch: m.stretch,
        lipPress: m.press,
      ),
      left: face.left,
      right: face.right,
      lipTuck: m.lipTuck,
      tongueUp: m.tongueUp,
      roll: face.roll,
      breath: face.breath,
      autoBlink: false,
      blinkSerial: face.blinkSerial,
    );
  }

  /// Whether [face]'s mouth is [viseme]'s shape.
  static bool hasViseme(FaceFrame face, Viseme viseme) {
    final MouthShape m = MouthShape.forViseme(viseme);
    return face.au.jawDrop == m.jaw &&
        face.au.lipPucker == m.pucker &&
        face.au.lipStretch == m.stretch &&
        face.au.lipPress == m.press &&
        face.lipTuck == m.lipTuck &&
        face.tongueUp == m.tongueUp;
  }

  /// [face] asking for one more blink.
  static FaceFrame withBlink(FaceFrame face) =>
      fromValues(values(face), blinkSerial: face.blinkSerial + 1);

  /// [face] as JSON: every number by name, plus [blinkKey].
  static Map<String, Object> toJson(FaceFrame face) => <String, Object>{
    ...values(face),
    blinkKey: face.blinkSerial,
  };

  /// Parses a face JSON object. Missing names are 0; unknown names, wrong
  /// types and out-of-range values throw a [FormatException].
  static FaceFrame fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw FormatException('"face" must be an object, got $json');
    }
    final Map<String, double> parsed = <String, double>{};
    int blinkSerial = 0;
    json.forEach((String key, Object? value) {
      if (key == blinkKey) {
        if (value is! int || value < 0) {
          throw FormatException(
            '"face.$key" must be a whole number >= 0, got $value',
          );
        }
        blinkSerial = value;
        return;
      }
      if (!numberKeys.contains(key)) {
        throw FormatException('Unknown face key "$key"');
      }
      if (value is! num || !value.isFinite) {
        throw FormatException('"face.$key" must be a number, got $value');
      }
      final (double min, double max) = range(key);
      if (value < min || value > max) {
        throw FormatException(
          '"face.$key" must be within $min..$max, got $value',
        );
      }
      parsed[key] = value.toDouble();
    });
    return fromValues(parsed, blinkSerial: blinkSerial);
  }

  static List<double> _sideList(ActionUnitSides s) => <double>[
    s.browInnerUp,
    s.browOuterUp,
    s.browLower,
    s.lidTighten,
    s.cheekRaise,
    s.lipCornerPull,
    s.lipCornerDepress,
  ];

  static ActionUnitSides _sides(List<double> v) => ActionUnitSides(
    browInnerUp: v[0],
    browOuterUp: v[1],
    browLower: v[2],
    lidTighten: v[3],
    cheekRaise: v[4],
    lipCornerPull: v[5],
    lipCornerDepress: v[6],
  );
}

AppGlassStyle _scaleFill(AppGlassStyle style, double scale) => AppGlassStyle(
  blurSigma: style.blurSigma,
  fillAlpha: (style.fillAlpha * scale).clamp(0.0, 1.0),
  borderAlpha: style.borderAlpha,
);

/// Applies the lab's manual overrides on top of the [base] look theme: the
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
    scene = ScenePalette.fromAccent(accent, ink: tokens.background);
    final Color onAccent = scene.onAccent;
    final Color container = Color.alphaBlend(
      accent.withValues(alpha: 0.25),
      scheme.surface,
    );
    scheme = scheme.copyWith(
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: container,
      secondary: accent,
      onSecondary: onAccent,
      secondaryContainer: container,
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
