import 'dart:ui' show Size;

/// The states of the composer's action orb. Names equal the `state` enum
/// values of the `ComposerOrb` artboard, in contract order.
enum ComposerOrbState { idle, typing, listening, thinking, speaking, error }

/// The tool kinds the `ToolIcon` artboard can draw. Names equal its `kind`
/// enum values, in contract order.
enum ToolIconKind { search, weather, news, memory, generic }

/// Dart mirror of the `assets/rive/ui/ui_kit.riv` section of
/// `rive/CONTRACT.md`, the single source of truth for every name below.
abstract final class UiKitContract {
  static const String assetPath = 'assets/rive/ui/ui_kit.riv';

  /// Every UI-kit artboard has a state machine with this name.
  static const String stateMachine = 'Main';

  // Artboards and their design sizes.
  static const String composerOrbArtboard = 'ComposerOrb';
  static const String statusGlowArtboard = 'StatusGlow';
  static const String toolIconArtboard = 'ToolIcon';
  static const String toggleArtboard = 'Toggle';
  static const String markArtboard = 'Mark';

  static const Size composerOrbSize = Size(96, 96);
  static const Size statusGlowSize = Size(480, 200);
  static const Size toolIconSize = Size(48, 48);
  static const Size toggleSize = Size(104, 64);
  static const Size markSize = Size(256, 256);

  // View models: one per artboard, named `<Artboard>VM`.
  static const String composerOrbViewModel = 'ComposerOrbVM';
  static const String statusGlowViewModel = 'StatusGlowVM';
  static const String toolIconViewModel = 'ToolIconVM';
  static const String toggleViewModel = 'ToggleVM';
  static const String markViewModel = 'MarkVM';

  // ComposerOrb properties.
  static const String orbPropState = 'state';
  static const String orbPropLevel = 'level';
  static const String orbPropAccent = 'accent';
  static const String orbPropOnAccent = 'onAccent';
  static const String orbPropReduceMotion = 'reduceMotion';
  static const List<String> orbStateValues = <String>[
    'idle',
    'typing',
    'listening',
    'thinking',
    'speaking',
    'error',
  ];
  static const double orbLevelMin = 0;
  static const double orbLevelMax = 1;

  // StatusGlow properties.
  static const String glowPropPhase = 'phase';
  static const String glowPropAccent = 'accent';
  static const String glowPropReduceMotion = 'reduceMotion';
  static const List<String> glowPhaseValues = <String>[
    'idle',
    'waiting',
    'generating',
    'speaking',
    'error',
  ];

  // ToolIcon properties.
  static const String toolPropKind = 'kind';
  static const String toolPropRunning = 'running';
  static const String toolPropTint = 'tint';
  static const List<String> toolKindValues = <String>[
    'search',
    'weather',
    'news',
    'memory',
    'generic',
  ];

  // Toggle properties.
  static const String togglePropValue = 'value';
  static const String togglePropAccent = 'accent';
  static const String togglePropTrack = 'track';
  static const String togglePropKnob = 'knob';

  // Mark properties.
  static const String markPropPlay = 'play';
  static const String markPropAccent = 'accent';
}
